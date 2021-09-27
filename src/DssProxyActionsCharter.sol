// SPDX-License-Identifier: AGPL-3.0-or-later

/// DssProxyActions.sol

// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.12;

interface GemLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface CharterLike {
    function vat() external view returns (address);
    function getOrCreateProxy(address) external returns (address);
    function join(address, address, uint256) external;
    function exit(address, address, uint256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function flux(bytes32, address, address, uint256) external;
    function quit(bytes32 ilk, address dst) external;
    function gate(bytes32) external view returns (uint256);
    function Nib(bytes32) external view returns (uint256);
    function nib(bytes32, address) external view returns (uint256);
}

interface VatLike {
    function can(address, address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function dai(address) external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function hope(address) external;
    function move(address, address, uint256) external;
    function flux(bytes32, address, address, uint256) external;
}

interface GemJoinLike {
    function dec() external returns (uint256);
    function gem() external returns (GemLike);
    function ilk() external returns (bytes32);
}

interface DaiJoinLike {
    function vat() external returns (VatLike);
    function dai() external returns (GemLike);
    function join(address, uint256) external payable;
    function exit(address, uint256) external;
}

interface EndLike {
    function fix(bytes32) external view returns (uint256);
    function cash(bytes32, uint256) external;
    function free(bytes32) external;
    function pack(uint256) external;
    function skim(bytes32, address) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint256);
}

interface HopeLike {
    function hope(address) external;
    function nope(address) external;
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a DSProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract Common {
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    // Internal functions

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    // Public functions

    function daiJoin_join(address apt, uint256 wad) public {
        // Gets DAI from the user's wallet
        DaiJoinLike(apt).dai().transferFrom(msg.sender, address(this), wad);
        // Approves adapter to take the DAI amount
        DaiJoinLike(apt).dai().approve(apt, wad);
        // Joins DAI into the vat
        DaiJoinLike(apt).join(address(this), wad);
    }
}

contract DssProxyActionsCharter is Common {
    // Internal functions

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint256 wad) internal pure returns (uint256 rad) {
        rad = mul(wad, 10 ** 27);
    }

    function convertTo18(address gemJoin, uint256 amt) internal returns (uint256 wad) {
        // For those collaterals that have less than 18 decimals precision we need to do the conversion before passing to frob function
        // Adapters will automatically handle the difference of precision
        wad = mul(
            amt,
            10 ** (18 - GemJoinLike(gemJoin).dec())
        );
    }

    function _getNet(
        address vat,
        address charter,
        bytes32 ilk,
        int256 dart,
        uint256 wad
    ) internal returns (uint256 wadN) {
        // Attain origination fee from ther charter manager
        uint256 nib = (CharterLike(charter).gate(ilk) == 1) ?
            CharterLike(charter).nib(ilk, address(this)) :
            CharterLike(charter).Nib(ilk);

        // If origination fee exists, use it to get net amount
        if (nib > 0) {
            (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
            uint256 dtab = mul(rate, uint256(dart)); // rad
            uint256 coin = mul(dtab, nib) / WAD;     // rad
            wadN = sub(dtab, coin) / RAY;
        } else {
            wadN = wad;
        }
    }

    function _getDrawDart(
        address vat,
        address jug,
        bytes32 ilk,
        uint256 wad
    ) internal returns (int256 dart) {
        // Updates stability fee rate
        uint256 rate = JugLike(jug).drip(ilk);

        // Gets DAI balance of the urn in the vat
        uint256 dai = VatLike(vat).dai(address(this));

        // If there was already enough DAI in the vat balance, just exits it without adding more debt
        if (dai < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = toInt256(sub(mul(wad, RAY), dai) / rate);
            // This is needed due lack of precision. It might need to sum an extra dart wei (for the given DAI wad amount)
            dart = mul(uint256(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function _getWipeDart(
        address vat,
        uint256 dai,
        address urn,
        bytes32 ilk
    ) internal view returns (int256 dart) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Uses the whole dai balance in the vat to reduce the debt
        dart = toInt256(dai / rate);
        // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
        dart = uint256(dart) <= art ? - dart : - toInt256(art);
    }

    function _getWipeAllWad(
        address vat,
        address urn,
        bytes32 ilk
    ) internal view returns (uint256 wad) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urn);
        // Gets actual dai amount in the urn
        uint256 dai = VatLike(vat).dai(address(this));

        uint256 rad = sub(mul(art, rate), dai);
        wad = rad / RAY;

        // If the rad precision has some dust, it will need to request for 1 extra wad wei
        wad = mul(wad, RAY) < rad ? wad + 1 : wad;
    }

    // Public functions

    function transfer(address gem, address dst, uint256 amt) public {
        GemLike(gem).transfer(dst, amt);
    }

    function ethJoin_join(address charter, address apt) public payable {
        // Wraps ETH in WETH
        GemJoinLike(apt).gem().deposit{value: msg.value}();
        // Approves adapter to take the WETH amount
        GemJoinLike(apt).gem().approve(charter, msg.value);
        // Joins WETH collateral into the vat
        CharterLike(charter).join(apt, address(this), msg.value);
    }

    function gemJoin_join(address charter, address apt, uint256 amt) public {
        // Gets token from the user's wallet
        GemJoinLike(apt).gem().transferFrom(msg.sender, address(this), amt);
        // Approves adapter to take the token amount
        GemJoinLike(apt).gem().approve(charter, amt);
        // Joins token collateral into the vat
        CharterLike(charter).join(apt, address(this), amt);
    }

    function hope(
        address obj,
        address usr
    ) public {
        HopeLike(obj).hope(usr);
    }

    function nope(
        address obj,
        address usr
    ) public {
        HopeLike(obj).nope(usr);
    }

    function flux(
        address charter,
        bytes32 ilk,
        address dst,
        uint256 wad
    ) public {
        CharterLike(charter).flux(ilk, address(this), dst, wad);
    }

    function move(
        address charter,
        address dst,
        uint256 rad
    ) public {
        VatLike(CharterLike(charter).vat()).move(address(this), dst, rad);
    }

    function frob(
        address charter,
        bytes32 ilk,
        int256 dink,
        int256 dart
    ) public {
        CharterLike(charter).frob(ilk, address(this), address(this), address(this), dink, dart);
    }

    function quit(
        address charter,
        bytes32 ilk,
        address dst
    ) public {
        CharterLike(charter).quit(ilk, dst);
    }

    function lockETH(
        address charter,
        address ethJoin
    ) public payable {
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(charter, ethJoin);
        // Locks WETH amount into the CDP
        frob(charter, GemJoinLike(ethJoin).ilk(), toInt256(msg.value), 0);
    }

    function lockGem(
        address charter,
        address gemJoin,
        uint256 amt
    ) public {
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(charter, gemJoin, amt);
        // Locks token amount into the CDP
        frob(charter, GemJoinLike(gemJoin).ilk(), toInt256(convertTo18(gemJoin, amt)), 0);
    }

    function freeETH(
        address charter,
        address ethJoin,
        uint256 wad
    ) public {
        bytes32 ilk = GemJoinLike(ethJoin).ilk();

        // Unlocks WETH amount from the CDP
        frob(charter, ilk, -toInt256(wad), 0);
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address charter,
        address gemJoin,
        uint256 amt
    ) public {
        bytes32 ilk = GemJoinLike(gemJoin).ilk();
        uint256 wad = convertTo18(gemJoin, amt);

        // Unlocks token amount from the CDP
        frob(charter, ilk, -toInt256(wad), 0);
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function exitETH(
        address charter,
        address ethJoin,
        uint256 wad
    ) public {
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function exitGem(
        address charter,
        address gemJoin,
        uint256 amt
    ) public {
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function draw(
        address charter,
        bytes32 ilk,
        address jug,
        address daiJoin,
        uint256 wad
    ) public {
        address vat = CharterLike(charter).vat();

        // Generates debt in the CDP
        int256 dart = _getDrawDart(vat, jug, ilk, wad);
        frob(charter, ilk, 0, dart);
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, _getNet(vat, charter, ilk, dart, wad));
    }

    function wipe(
        address charter,
        bytes32 ilk,
        address daiJoin,
        uint256 wad
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, wad);
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        // Paybacks debt to the CDP
        frob(charter, ilk, 0, _getWipeDart(vat, VatLike(vat).dai(address(this)), urn, ilk));
    }

    function wipeAll(
        address charter,
        bytes32 ilk,
        address daiJoin
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, _getWipeAllWad(vat, urn, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        // Paybacks debt to the CDP
        frob(charter, ilk, 0, -int256(art));
    }

    function lockETHAndDraw(
        address charter,
        address jug,
        address ethJoin,
        address daiJoin,
        uint256 wadD
    ) public payable {
        address vat = CharterLike(charter).vat();
        bytes32 ilk = GemJoinLike(ethJoin).ilk();

        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(charter, ethJoin);
        // Locks WETH amount into the CDP and generates debt
        int256 dart = _getDrawDart(vat, jug, ilk, wadD);
        frob(charter, ilk, toInt256(msg.value), dart);
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, _getNet(vat, charter, ilk, dart, wadD));
    }

    function lockGemAndDraw(
        address charter,
        address jug,
        address gemJoin,
        address daiJoin,
        uint256 amtC,
        uint256 wadD
    ) public {
        address vat = CharterLike(charter).vat();
        bytes32 ilk = GemJoinLike(gemJoin).ilk();

        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(charter, gemJoin, amtC);
        // Locks token amount into the CDP and generates debt
        int256 dink = toInt256(convertTo18(gemJoin, amtC));
        int256 dart = _getDrawDart(vat, jug, ilk, wadD);
        frob(charter, ilk, dink, dart);
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, _getNet(vat, charter, ilk, dart, wadD));
    }

    function wipeAndFreeETH(
        address charter,
        address ethJoin,
        address daiJoin,
        uint256 wadC,
        uint256 wadD
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(ethJoin).ilk();

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, wadD);
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(charter, ilk, -toInt256(wadC), _getWipeDart(vat, VatLike(vat).dai(address(this)), urn, ilk));
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAllAndFreeETH(
        address charter,
        address ethJoin,
        address daiJoin,
        uint256 wadC
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(ethJoin).ilk();
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, _getWipeAllWad(vat, urn, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(charter, ilk, -toInt256(wadC), -int256(art));
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAndFreeGem(
        address charter,
        address gemJoin,
        address daiJoin,
        uint256 amtC,
        uint256 wadD
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(gemJoin).ilk();

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, wadD);
        uint256 wadC = convertTo18(gemJoin, amtC);
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(charter, ilk, -toInt256(wadC), _getWipeDart(vat, VatLike(vat).dai(address(this)), urn, ilk));
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amtC);
    }

    function wipeAllAndFreeGem(
        address charter,
        address gemJoin,
        address daiJoin,
        uint256 amtC
    ) public {
        address vat = CharterLike(charter).vat();
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(gemJoin).ilk();
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, _getWipeAllWad(vat, urn, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(charter)) == 0) {
            VatLike(vat).hope(charter);
        }
        uint256 wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(charter, ilk, -toInt256(wadC), -int256(art));
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amtC);
    }
}

contract DssProxyActionsEndCharter is Common {
    // Internal functions

    function _free(
        address charter,
        address end,
        bytes32 ilk
    ) internal returns (uint256 ink) {
        VatLike vat = VatLike(CharterLike(charter).vat());
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        uint256 art;
        (ink, art) = vat.urns(ilk, urn);

        // If CDP still has debt, it needs to be paid
        if (art > 0) {
            EndLike(end).skim(ilk, urn);
            (ink,) = vat.urns(ilk, urn);
        }
        // Approves the charter to transfer the position to proxy's address in the vat
        if (vat.can(address(this), address(charter)) == 0) {
            vat.hope(charter);
        }
        // Transfers position from CDP to the proxy address
        CharterLike(charter).quit(ilk, address(this));
        // Frees the position and recovers the collateral in the vat registry
        EndLike(end).free(ilk);
    }

    // Public functions
    function freeETH(
        address charter,
        address ethJoin,
        address end
    ) public {
        VatLike vat = VatLike(CharterLike(charter).vat());
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(ethJoin).ilk();

        // Frees the position through the end contract
        uint256 wad = _free(charter, end, ilk);
        // Fluxs to the proxy's manager proxy, so it can be pulled out with the managed gem join
        vat.flux(ilk, address(this), urn, wad);
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address charter,
        address gemJoin,
        address end
    ) public {
        VatLike vat = VatLike(CharterLike(charter).vat());
        address urn = CharterLike(charter).getOrCreateProxy(address(this));
        bytes32 ilk = GemJoinLike(gemJoin).ilk();

        // Frees the position through the end contract
        uint256 wad = _free(charter, end, ilk);
        // Fluxs to the proxy's manager proxy, so it can be pulled out with the managed gem join
        vat.flux(ilk, address(this), urn, wad);
        // Exits token amount to the user's wallet as a token
        uint256 amt = wad / 10 ** (18 - GemJoinLike(gemJoin).dec());
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function pack(
        address daiJoin,
        address end,
        uint256 wad
    ) public {
        VatLike vat = DaiJoinLike(daiJoin).vat();

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, wad);
        // Approves the end to take out DAI from the proxy's balance in the vat
        if (vat.can(address(this), address(end)) == 0) {
            vat.hope(end);
        }
        EndLike(end).pack(wad);
    }

    function cashETH(
        address charter,
        address ethJoin,
        address end,
        bytes32 ilk,
        uint256 wad
    ) public {
        VatLike vat = VatLike(CharterLike(charter).vat());
        address urn = CharterLike(charter).getOrCreateProxy(address(this));

        EndLike(end).cash(ilk, wad);
        uint256 wadC = mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Flux to the proxy's UrnProxy in charter manager, so it can be pulled out with the managed gem join
        vat.flux(ilk, address(this), urn, wadC);
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function cashGem(
        address charter,
        address gemJoin,
        address end,
        bytes32 ilk,
        uint256 wad
    ) public {
        VatLike vat = VatLike(CharterLike(charter).vat());
        address urn = CharterLike(charter).getOrCreateProxy(address(this));

        EndLike(end).cash(ilk, wad);
        uint256 wadC = mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Flux to the proxy's UrnProxy in charter manager, so it can be pulled out with the managed gem join
        vat.flux(ilk, address(this), urn, wadC);
        // Exits token amount to the user's wallet as a token
        uint256 amt = wadC / 10 ** (18 - GemJoinLike(gemJoin).dec());
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }
}
