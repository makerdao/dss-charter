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
    function getOrCreateProxy(address) external returns (address);
    function join(address, address, uint256) external;
    function exit(address, address, uint256) external;
    function roll(bytes32, bytes32, address, address, uint256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function quit(bytes32, address, address) external;
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
    function nope(address) external;
    function flux(bytes32, address, address, uint256) external;
}

interface GemJoinLike {
    function dec() external returns (uint256);
    function gem() external returns (GemLike);
    function ilk() external returns (bytes32);
}

interface DaiJoinLike {
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

interface CdpRegistryLike {
    function owns(uint256) external view returns (address);
    function ilks(uint256) external view returns (bytes32);
    function open(bytes32, address) external returns (uint256);
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a DSProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract Common {
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    address immutable public vat;
    address immutable public charter;
    address immutable public cdpRegistry;

    constructor(address vat_, address charter_, address cdpRegistry_) public {
        vat = vat_;
        charter = charter_;
        cdpRegistry = cdpRegistry_;
    }

    // Internal functions

    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    // Public functions

    function daiJoin_join(address daiJoin, address u, uint256 wad) public {
        GemLike dai = DaiJoinLike(daiJoin).dai();
        // Gets DAI from the user's wallet
        dai.transferFrom(msg.sender, address(this), wad);
        // Approves adapter to take the DAI amount
        dai.approve(daiJoin, wad);
        // Joins DAI into the vat
        DaiJoinLike(daiJoin).join(u, wad);
    }
}

contract DssProxyActionsCharter is Common {

    constructor(address vat_, address charter_, address cdpRegistry_) public Common(vat_, charter_, cdpRegistry_) {}

    // Internal functions

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function _toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int-overflow");
    }

    function _convertTo18(address gemJoin, uint256 amt) internal returns (uint256 wad) {
        // For those collaterals that have less than 18 decimals precision we
        //   need to do the conversion before passing to frob function
        // Adapters will automatically handle the difference of precision
        wad = _mul(
            amt,
            10 ** (18 - GemJoinLike(gemJoin).dec())
        );
    }

    function _getDrawDart(
        address jug,
        address u,
        bytes32 ilk,
        uint256 wad
    )  internal returns (int256 dart) {
        // Updates stability fee rate
        uint256 rate = JugLike(jug).drip(ilk);

        // Gets DAI balance of the urn in the vat
        uint256 dai = VatLike(vat).dai(u);

        // If there was already enough DAI in the vat balance,
        //    just exits it without adding more debt
        uint256 rad = _mul(wad, RAY);
        if (dai < rad) {
            uint256 netToDraw = rad - dai; // dai < rad

            uint256 nib = (CharterLike(charter).gate(ilk) == 1) ?
                CharterLike(charter).nib(ilk, u) :
                CharterLike(charter).Nib(ilk);

            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = _toInt256(_mul(netToDraw, WAD) / _sub(_mul(rate, WAD), _mul(rate, nib))); // wad
            uint256 dtab = _mul(uint256(dart), rate);
            // This is needed due lack of precision, it might need to sum an extra dart wei
            dart = _sub(dtab, _mul(dtab, nib) / WAD) < netToDraw ? dart + 1 : dart;
        }
    }

    function _getWipeDart(
        uint256 dai,
        address urp,
        bytes32 ilk
    ) internal view returns (int256 dart) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urp);

        // Uses the whole dai balance in the vat to reduce the debt
        dart = _toInt256(dai / rate);
        // Checks the calculated dart is not higher than urn.art (total debt),
        //    otherwise uses its value
        dart = uint256(dart) <= art ? - dart : - _toInt256(art);
    }

    function _getWipeAllWad(
        address u,
        address urp,
        bytes32 ilk
    ) internal view returns (uint256 wad) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urp);

        // Gets DAI balance of the urn in the vat
        uint256 dai = VatLike(vat).dai(u);

        // If there was already enough DAI in the vat balance, no need to join more
        uint256 debt = _mul(art, rate);
        if (debt > dai) {
            uint256 rad = _sub(debt, dai);
            wad = rad / RAY;

            // If the rad precision has some dust, it will need to request for 1 extra wad wei
            wad = _mul(wad, RAY) < rad ? wad + 1 : wad;
        }
    }

    function _frob(
        bytes32 ilk,
        address u,
        int256 dink,
        int256 dart
    ) internal {
        CharterLike(charter).frob(ilk, u, u, u, dink, dart);
    }

    function _ethJoin_join(address ethJoin, address u) internal {
        GemLike gem = GemJoinLike(ethJoin).gem();
        // Wraps ETH in WETH
        gem.deposit{value: msg.value}();
        // Approves adapter to take the WETH amount
        gem.approve(charter, msg.value);
        // Joins WETH collateral into the vat
        CharterLike(charter).join(ethJoin, u, msg.value);
    }

    function _gemJoin_join(address gemJoin, address u, uint256 amt) internal {
        GemLike gem = GemJoinLike(gemJoin).gem();
        // Gets token from the user's wallet
        gem.transferFrom(msg.sender, address(this), amt);
        // Approves adapter to take the token amount
        gem.approve(charter, amt);
        // Joins token collateral into the vat
        CharterLike(charter).join(gemJoin, u, amt);
    }

    // Public functions

    function transfer(address gem, address dst, uint256 amt) external {
        GemLike(gem).transfer(dst, amt);
    }

    function hope(
        address obj,
        address usr
    ) external {
        HopeLike(obj).hope(usr);
    }

    function nope(
        address obj,
        address usr
    ) external {
        HopeLike(obj).nope(usr);
    }

    function open(
        bytes32 ilk,
        address usr
    ) external returns (uint256 cdp) {
        cdp = CdpRegistryLike(cdpRegistry).open(ilk, usr);
    }

    function quit(
        uint256 cdp,
        address dst
    ) external {
        CharterLike(charter).quit(
            CdpRegistryLike(cdpRegistry).ilks(cdp),
            CdpRegistryLike(cdpRegistry).owns(cdp),
            dst
        );
    }

    function lockETH(
        address ethJoin,
        uint256 cdp
    ) external payable {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);

        // Receives ETH amount, converts it to WETH and joins it into the vat
        _ethJoin_join(ethJoin, owner);
        // Locks WETH amount into the CDP
        _frob(CdpRegistryLike(cdpRegistry).ilks(cdp), owner, _toInt256(msg.value), 0);
    }

    function lockGem(
        address gemJoin,
        uint256 cdp,
        uint256 amt
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);

        // Takes token amount from user's wallet and joins into the vat
        _gemJoin_join(gemJoin, owner, amt);
        // Locks token amount into the CDP
        _frob(CdpRegistryLike(cdpRegistry).ilks(cdp), owner, _toInt256(_convertTo18(gemJoin, amt)), 0);
    }

    function freeETH(
        address ethJoin,
        uint256 cdp,
        uint256 wad
    ) external {
        // Unlocks WETH amount from the CDP
        _frob(
            CdpRegistryLike(cdpRegistry).ilks(cdp),
            CdpRegistryLike(cdpRegistry).owns(cdp),
            -_toInt256(wad),
            0
        );
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address gemJoin,
        uint256 cdp,
        uint256 amt
    ) external {
        // Unlocks token amount from the CDP
        _frob(
            CdpRegistryLike(cdpRegistry).ilks(cdp),
            CdpRegistryLike(cdpRegistry).owns(cdp),
            -_toInt256(_convertTo18(gemJoin, amt)),
            0
        );
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function exitETH(
        address ethJoin,
        uint256 cdp,
        uint256 wad
    ) external {
        require(CdpRegistryLike(cdpRegistry).owns(cdp) == address(this), "wrong-cdp");
        require(CdpRegistryLike(cdpRegistry).ilks(cdp) == GemJoinLike(ethJoin).ilk(), "wrong-ilk");

        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function exitGem(
        address gemJoin,
        uint256 cdp,
        uint256 amt
    ) external {
        require(CdpRegistryLike(cdpRegistry).owns(cdp) == address(this), "wrong-cdp");
        require(CdpRegistryLike(cdpRegistry).ilks(cdp) == GemJoinLike(gemJoin).ilk(), "wrong-ilk");

        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function draw(
        address jug,
        address daiJoin,
        uint256 cdp,
        uint256 wad
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Generates debt in the CDP
        _frob(ilk, owner, 0, _getDrawDart(jug, owner, ilk, wad));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wad);
    }

    function wipe(
        address daiJoin,
        uint256 cdp,
        uint256 wad
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, wad);
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP
        _frob(
            ilk,
            owner,
            0,
            _getWipeDart(
                VatLike(vat).dai(owner),
                CharterLike(charter).getOrCreateProxy(owner),
                ilk
            )
        );
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
    }

    function wipeAll(
        address daiJoin,
        uint256 cdp
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        address urp = CharterLike(charter).getOrCreateProxy(owner);
        (, uint256 art) = VatLike(vat).urns(ilk, urp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, _getWipeAllWad(owner, urp, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP
        _frob(ilk, owner, 0, -_toInt256(art));
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
    }

    function lockETHAndDraw(
        address jug,
        address ethJoin,
        address daiJoin,
        uint256 cdp,
        uint256 wadD
    ) public payable {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Receives ETH amount, converts it to WETH and joins it into the vat
        _ethJoin_join(ethJoin, owner);
        // Locks WETH amount into the CDP and generates debt
        _frob(
            ilk,
            owner,
            _toInt256(msg.value),
            _getDrawDart(
                jug,
                owner,
                ilk,
                wadD
            )
        );
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function openLockETHAndDraw(
        address jug,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) public payable returns (uint256 cdp) {
        cdp = CdpRegistryLike(cdpRegistry).open(ilk, address(this));
        lockETHAndDraw(jug, ethJoin, daiJoin, cdp, wadD);
    }

    function lockGemAndDraw(
        address jug,
        address gemJoin,
        address daiJoin,
        uint256 cdp,
        uint256 amtC,
        uint256 wadD
    ) public {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Takes token amount from user's wallet and joins into the vat
        _gemJoin_join(gemJoin, owner, amtC);
        // Locks token amount into the CDP and generates debt
        _frob(
            ilk,
            owner,
            _toInt256(_convertTo18(gemJoin, amtC)),
            _getDrawDart(
                jug,
                owner,
                ilk,
                wadD
            )
        );
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function openLockGemAndDraw(
        address jug,
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 amtC,
        uint256 wadD
    ) public returns (uint256 cdp) {
        cdp = CdpRegistryLike(cdpRegistry).open(ilk, address(this));
        lockGemAndDraw(jug, gemJoin, daiJoin, cdp, amtC, wadD);
    }

    function wipeAndFreeETH(
        address ethJoin,
        address daiJoin,
        uint256 cdp,
        uint256 wadC,
        uint256 wadD
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, wadD);
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP and unlocks WETH amount from it
        _frob(
            ilk,
            owner,
            -_toInt256(wadC),
            _getWipeDart(
                VatLike(vat).dai(owner),
                CharterLike(charter).getOrCreateProxy(owner),
                ilk
            )
        );
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAllAndFreeETH(
        address ethJoin,
        address daiJoin,
        uint256 cdp,
        uint256 wadC
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        address urp = CharterLike(charter).getOrCreateProxy(owner);
        (, uint256 art) = VatLike(vat).urns(ilk, urp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, _getWipeAllWad(owner, urp, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP and unlocks WETH amount from it
        _frob(ilk, owner, -_toInt256(wadC), -_toInt256(art));
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAndFreeGem(
        address gemJoin,
        address daiJoin,
        uint256 cdp,
        uint256 amtC,
        uint256 wadD
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, wadD);
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP and unlocks token amount from it
        _frob(
            ilk,
            owner,
            -_toInt256(_convertTo18(gemJoin, amtC)),
            _getWipeDart(
                VatLike(vat).dai(owner),
                CharterLike(charter).getOrCreateProxy(owner),
                ilk
            )
        );
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amtC);
    }

    function wipeAllAndFreeGem(
        address gemJoin,
        address daiJoin,
        uint256 cdp,
        uint256 amtC
    ) external {
        address owner = CdpRegistryLike(cdpRegistry).owns(cdp);
        bytes32 ilk = CdpRegistryLike(cdpRegistry).ilks(cdp);

        address urp = CharterLike(charter).getOrCreateProxy(owner);
        (, uint256 art) = VatLike(vat).urns(ilk, urp);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, owner, _getWipeAllWad(owner, urp, ilk));
        // Allows charter to access to proxy's DAI balance in the vat
        VatLike(vat).hope(charter);
        // Paybacks debt to the CDP and unlocks token amount from it
        _frob(ilk, owner, -_toInt256(_convertTo18(gemJoin, amtC)), -_toInt256(art));
        // Denies charter to access to proxy's DAI balance in the vat after execution
        VatLike(vat).nope(charter);
        // Exits token amount to the user's wallet as a token
        CharterLike(charter).exit(gemJoin, msg.sender, amtC);
    }

    function roll(
        uint256 srcCdp,
        uint256 dstCdp,
        uint256 wad
    ) external {
        bytes32 srcIlk = CdpRegistryLike(cdpRegistry).ilks(srcCdp);

        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(srcIlk);
        CharterLike(charter).roll(
            srcIlk,
            CdpRegistryLike(cdpRegistry).ilks(dstCdp),
            CdpRegistryLike(cdpRegistry).owns(srcCdp),
            CdpRegistryLike(cdpRegistry).owns(dstCdp),
            _mul(wad, RAY) / rate
        );
    }
}

contract DssProxyActionsEndCharter is Common {

    constructor(address vat_, address charter_, address cdpRegistry_) public Common(vat_, charter_, cdpRegistry_) {}

    // Internal functions

    function _free(
        address end,
        address u,
        bytes32 ilk
    ) internal returns (uint256 ink) {
        address urp = CharterLike(charter).getOrCreateProxy(u);
        uint256 art;
        (ink, art) = VatLike(vat).urns(ilk, urp);

        // If CDP still has debt, it needs to be paid
        if (art > 0) {
            EndLike(end).skim(ilk, urp);
            (ink,) = VatLike(vat).urns(ilk, urp);
        }
        // Approves the charter to transfer the position to proxy's address in the vat
        VatLike(vat).hope(charter);
        // Transfers position from CDP to the proxy address
        CharterLike(charter).quit(ilk, u, address(this));
        // Denies charter to access to proxy's position in the vat after execution
        VatLike(vat).nope(charter);
        // Frees the position and recovers the collateral in the vat registry
        EndLike(end).free(ilk);
        // Fluxs to the proxy's charter proxy, so it can be pulled out with the managed gem join
        VatLike(vat).flux(
            ilk,
            address(this),
            urp,
            ink
        );
    }

    // Public functions
    function freeETH(
        address ethJoin,
        address end,
        uint256 cdp
    ) external {
        // Frees the position through the end contract
        uint256 wad = _free(end, CdpRegistryLike(cdpRegistry).owns(cdp), CdpRegistryLike(cdpRegistry).ilks(cdp));
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address gemJoin,
        address end,
        uint256 cdp
    ) external {
        // Frees the position through the end contract
        uint256 wad = _free(end, CdpRegistryLike(cdpRegistry).owns(cdp), CdpRegistryLike(cdpRegistry).ilks(cdp));
        // Exits token amount to the user's wallet as a token
        uint256 amt = wad / 10 ** (18 - GemJoinLike(gemJoin).dec());
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }

    function pack(
        address daiJoin,
        address end,
        uint256 wad
    ) external {
        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, address(this), wad);
        // Approves the end to take out DAI from the proxy's balance in the vat
        if (VatLike(vat).can(address(this), address(end)) == 0) {
            VatLike(vat).hope(end);
        }
        EndLike(end).pack(wad);
    }

    function cashETH(
        address ethJoin,
        address end,
        uint256 wad
    ) external {
        bytes32 ilk = GemJoinLike(ethJoin).ilk();
        EndLike(end).cash(ilk, wad);
        uint256 wadC = _mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Flux to the proxy's UrnProxy in charter, so it can be pulled out with the managed gem join
        VatLike(vat).flux(
            ilk,
            address(this),
            CharterLike(charter).getOrCreateProxy(address(this)),
            wadC
        );
        // Exits WETH amount to proxy address as a token
        CharterLike(charter).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function cashGem(
        address gemJoin,
        address end,
        uint256 wad
    ) external {
        bytes32 ilk = GemJoinLike(gemJoin).ilk();
        EndLike(end).cash(ilk, wad);
        uint256 wadC = _mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Flux to the proxy's UrnProxy in charter, so it can be pulled out with the managed gem join
        VatLike(vat).flux(
            ilk,
            address(this),
            CharterLike(charter).getOrCreateProxy(address(this)),
            wadC
        );
        // Exits token amount to the user's wallet as a token
        uint256 amt = wadC / 10 ** (18 - GemJoinLike(gemJoin).dec());
        CharterLike(charter).exit(gemJoin, msg.sender, amt);
    }
}
