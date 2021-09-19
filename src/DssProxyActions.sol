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

pragma solidity >=0.5.12;

interface GemLike {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
}

// TODO - replace name with charter manager
interface ManagerLike {
    function vat() external view returns (address);
    function proxy(address) external view returns (address);
    function can(address, address) external view returns (uint);
    function hope(address) external;
    function nope(address) external;
    function getOrCreateProxy(address) external returns (address);
    function join(address, address, uint256) external;
    function exit(address, address, uint256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function flux(bytes32, address, address, uint256) external;
    function quit(bytes32 ilk, address dst) external;
}

// TODO: remove unneeded stuff from here (move is needed so proxy can use it)
interface VatLike {
    function can(address, address) external view returns (uint);
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function dai(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint);
    function hope(address) external;
    function move(address, address, uint) external;
}

// TODO - reame to managed gem join
interface GemJoinLike {
    function dec() external returns (uint);
    function gem() external returns (GemLike);
    function ilk() external returns (bytes32);
    //function join(address, uint) external payable;
    //function exit(address, address, uint) external;
}

// TODO - remove, we do't allow direct access to join
interface GNTJoinLike {
    function bags(address) external view returns (address);
    function make(address) external returns (address);
}

interface DaiJoinLike {
    function vat() external returns (VatLike);
    function dai() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface HopeLike {
    function hope(address) external;
    function nope(address) external;
}

interface EndLike {
    function fix(bytes32) external view returns (uint);
    function cash(bytes32, uint) external;
    function free(bytes32) external;
    function pack(uint) external;
    function skim(bytes32, address) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint);
}

interface PotLike {
    function pie(address) external view returns (uint);
    function drip() external returns (uint);
    function join(uint) external;
    function exit(uint) external;
}

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a DSProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract Common {
    uint256 constant RAY = 10 ** 27;

    // Internal functions

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    // Public functions

    function daiJoin_join(address apt, address urn, uint wad) public {
        // Gets DAI from the user's wallet
        DaiJoinLike(apt).dai().transferFrom(msg.sender, address(this), wad);
        // Approves adapter to take the DAI amount
        DaiJoinLike(apt).dai().approve(apt, wad);
        // Joins DAI into the vat
        DaiJoinLike(apt).join(urn, wad);
    }
}

contract DssProxyActions is Common {
    // Internal functions

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
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

    function _getDrawDart(
        address vat,
        address jug,
        address urn,
        bytes32 ilk,
        uint wad
    ) internal returns (int dart) {
        // Updates stability fee rate
        uint rate = JugLike(jug).drip(ilk);

        // Gets DAI balance of the urn in the vat
        uint dai = VatLike(vat).dai(urn);

        // If there was already enough DAI in the vat balance, just exits it without adding more debt
        if (dai < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = toInt(sub(mul(wad, RAY), dai) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given DAI wad amount)
            dart = mul(uint(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function _getWipeDart(
        address vat,
        uint dai,
        address urn,
        bytes32 ilk
    ) internal view returns (int dart) {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint art) = VatLike(vat).urns(ilk, urn);

        // Uses the whole dai balance in the vat to reduce the debt
        dart = toInt(dai / rate);
        // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
        dart = uint(dart) <= art ? - dart : - toInt(art);
    }

    function _getWipeAllWad(
        address vat,
        address usr,
        address urn,
        bytes32 ilk
    ) internal view returns (uint wad) {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint art) = VatLike(vat).urns(ilk, urn);
        // Gets actual dai amount in the urn
        uint dai = VatLike(vat).dai(usr);

        uint rad = sub(mul(art, rate), dai);
        wad = rad / RAY;

        // If the rad precision has some dust, it will need to request for 1 extra wad wei
        wad = mul(wad, RAY) < rad ? wad + 1 : wad;
    }

    // Public functions
    function transfer(address gem, address dst, uint amt) public {
        GemLike(gem).transfer(dst, amt);
    }

    function ethJoin_join(address manager, address apt, address usr) public payable {
        // Wraps ETH in WETH
        GemJoinLike(apt).gem().deposit.value(msg.value)();
        // Approves adapter to take the WETH amount
        GemJoinLike(apt).gem().approve(address(apt), msg.value);
        // Joins WETH collateral into the vat
        ManagerLike(manager).join(apt, usr, msg.value);
    }

    function gemJoin_join(address manager, address apt, address usr, uint amt, bool transferFrom) public {
        // Only executes for tokens that have approval/transferFrom implementation
        if (transferFrom) {
            // Gets token from the user's wallet
            GemJoinLike(apt).gem().transferFrom(msg.sender, address(this), amt);
            // Approves adapter to take the token amount
            GemJoinLike(apt).gem().approve(apt, amt);
        }
        // Joins token collateral into the vat
        ManagerLike(manager).join(apt, usr, amt);
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

    function getOrCreateProxy(address manager, address usr) public returns (address urp) {
        urp = ManagerLike(manager).getOrCreateProxy(usr);
    }

    function flux(
        address manager,
        bytes32 ilk,
        address src,
        address dst,
        uint wad
    ) public {
        ManagerLike(manager).flux(ilk, src, dst, wad);
    }

    function move(
        address manager,
        address src,
        address dst,
        uint rad
    ) public {
        VatLike(ManagerLike(manager).vat()).move(src, dst, rad);
    }

    function frob(
        address manager,
        bytes32 ilk,
        address usr,
        int dink,
        int dart
    ) public {
        ManagerLike(manager).frob(ilk, usr, usr, address(this), dink, dart);
    }

    function quit(
        address manager,
        bytes32 ilk,
        address dst
    ) public {
        ManagerLike(manager).quit(ilk, dst);
    }


    // TODO: remove this ???
    function makeGemBag(
        address gemJoin
    ) public returns (address bag) {
        bag = GNTJoinLike(gemJoin).make(address(this));
    }

    function lockETH(
        address manager,
        address ethJoin,
        address usr
    ) public payable {
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(manager, ethJoin, address(this));
        // Locks WETH amount into the CDP
        ManagerLike(manager).frob(
            GemJoinLike(ethJoin).ilk(),
            usr,
            address(this),
            address(this),
            toInt(msg.value),
            0
        );
    }

    function lockGem(
        address manager,
        address gemJoin,
        address usr,
        uint amt,
        bool transferFrom
    ) public {
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(manager, gemJoin, address(this), amt, transferFrom);
        // Locks token amount into the CDP
        ManagerLike(manager).frob(
            GemJoinLike(gemJoin).ilk(),
            usr,
            address(this),
            address(this),
            toInt(convertTo18(gemJoin, amt)),
            0
        );
    }

    function freeETH(
        address manager,
        address ethJoin,
        address usr,
        uint wad
    ) public {
        // Unlocks WETH amount from the CDP
        frob(manager, GemJoinLike(ethJoin).ilk(), usr, -toInt(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, GemJoinLike(ethJoin).ilk(), usr, address(this), wad);
        // Exits WETH amount to proxy address as a token
        ManagerLike(manager).exit(ethJoin, address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address manager,
        address gemJoin,
        address usr,
        uint amt
    ) public {
        uint wad = convertTo18(gemJoin, amt);
        // Unlocks token amount from the CDP
        frob(manager, GemJoinLike(gemJoin).ilk(), usr, -toInt(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, GemJoinLike(gemJoin).ilk(), usr, address(this), wad);
        // Exits token amount to the user's wallet as a token
        ManagerLike(manager).exit(gemJoin, msg.sender, amt);
    }

    function exitETH(
        address manager,
        address ethJoin,
        address usr,
        uint wad
    ) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, GemJoinLike(ethJoin).ilk(), usr, address(this), wad);

        // Exits WETH amount to proxy address as a token
        ManagerLike(manager).exit(ethJoin, address(this), wad);

        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function exitGem(
        address manager,
        address gemJoin,
        address usr,
        uint amt
    ) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, GemJoinLike(gemJoin).ilk(), usr, address(this), convertTo18(gemJoin, amt));

        // Exits token amount to the user's wallet as a token
        ManagerLike(manager).exit(gemJoin, msg.sender, amt);
    }

    function draw(
        address manager,
        bytes32 ilk, // TODO - do we must add this?
        address jug,
        address daiJoin,
        address usr,
        uint wad
    ) public {
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        address vat = ManagerLike(manager).vat();
        // Generates debt in the CDP
        frob(manager, ilk, usr, 0, _getDrawDart(vat, jug, urn, ilk, wad));
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(manager, usr, address(this), toRad(wad));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wad);
    }

    function wipe(
        address manager,
        bytes32 ilk, // TODO - do we must add this?
        address daiJoin,
        address usr,
        uint wad
    ) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).getOrCreateProxy(usr);

        // Note: in DssCharter's frob w must be the msg.sender, so it must be address(this)

        daiJoin_join(daiJoin, address(this), wad);
        ManagerLike(manager).frob(
            ilk,
            usr,
            address(this),
            address(this),
            _getWipeDart(vat, wad * RAY, urn, ilk),
            0
        );
    }

    function wipeAll(
        address manager,
        bytes32 ilk, // TODO - do we must add this?
        address daiJoin,
        address usr
    ) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        (, uint art) = VatLike(vat).urns(ilk, urn);

        // Note: in DssCharter's frob w must be the msg.sender, so it must be address(this)

        daiJoin_join(daiJoin, address(this), _getWipeAllWad(vat, address(this), urn, ilk));
        ManagerLike(manager).frob(
            ilk,
            usr,
            address(this),
            address(this),
            0,
            -int(art)
        );
    }

    function lockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address daiJoin,
        address usr,
        uint wadD
    ) public payable {
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        address vat = ManagerLike(manager).vat();

        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(manager, ethJoin, usr);
        // Locks WETH amount into the CDP and generates debt
        frob(manager, GemJoinLike(ethJoin).ilk(), usr, toInt(msg.value), _getDrawDart(vat, jug, urn, GemJoinLike(ethJoin).ilk(), wadD));

        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(manager, usr, address(this), toRad(wadD));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function lockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address daiJoin,
        address usr,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) public {
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        address vat = ManagerLike(manager).vat();

        int dink = toInt(convertTo18(gemJoin, amtC));
        int dart = _getDrawDart(vat, jug, urn, GemJoinLike(gemJoin).ilk(), wadD);

        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(manager, gemJoin, usr, amtC, transferFrom);
        // Locks token amount into the CDP and generates debt
        frob(manager, GemJoinLike(gemJoin).ilk(), usr, dink, dart);
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(manager, usr, address(this), toRad(wadD));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function wipeAndFreeETH(
        address manager,
        address ethJoin,
        address daiJoin,
        address usr,
        uint wadC,
        uint wadD
    ) public {
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, address(this), wadD);
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(
            manager,
            GemJoinLike(ethJoin).ilk(),
            usr,
            -toInt(wadC),
            _getWipeDart(ManagerLike(manager).vat(), VatLike(ManagerLike(manager).vat()).dai(urn), urn, GemJoinLike(ethJoin).ilk())
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager,  GemJoinLike(ethJoin).ilk(), usr, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        ManagerLike(manager).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAllAndFreeETH(
        address manager,
        address ethJoin,
        address daiJoin,
        address usr,
        uint wadC
    ) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        bytes32 ilk = GemJoinLike(ethJoin).ilk();
        (, uint art) = VatLike(vat).urns(ilk, urn);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, address(this), _getWipeAllWad(vat, address(this), urn, ilk));
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(
            manager,
            ilk,
            usr,
            -toInt(wadC),
            -int(art)
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, ilk, usr, address(this), wadC);

        // Exits WETH amount to proxy address as a token
        ManagerLike(manager).exit(ethJoin, address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAndFreeGem(
        address manager,
        address gemJoin,
        address daiJoin,
        address usr,
        uint amtC,
        uint wadD
    ) public {
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        bytes32 ilk = GemJoinLike(gemJoin).ilk();
        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, address(this), wadD);

        uint wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            manager,
            ilk,
            usr,
            -toInt(wadC),
            _getWipeDart(ManagerLike(manager).vat(), VatLike(ManagerLike(manager).vat()).dai(address(this)), urn, ilk)
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, ilk, usr, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        ManagerLike(manager).exit(gemJoin, address(this), wadC);
    }

    function wipeAllAndFreeGem(
        address manager,
        address gemJoin,
        address daiJoin,
        address usr,
        uint amtC
    ) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).getOrCreateProxy(usr);
        bytes32 ilk = GemJoinLike(gemJoin).ilk();
        (, uint art) = VatLike(vat).urns(ilk, urn);

        // Joins DAI amount into the vat
        daiJoin_join(daiJoin, address(this), _getWipeAllWad(vat, address(this), urn, ilk));
        uint wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            manager,
            ilk,
            usr,
            -toInt(wadC),
            -int(art)
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, ilk, usr, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        ManagerLike(manager).exit(gemJoin, address(this), amtC);
    }
}

/* TODO - implement more contracts
contract DssProxyActionsEnd is Common {
    // Internal functions

    function _free(
        address manager,
        address end,
        uint cdp
    ) internal returns (uint ink) {
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        address urn = ManagerLike(manager).urns(cdp);
        VatLike vat = VatLike(ManagerLike(manager).vat());
        uint art;
        (ink, art) = vat.urns(ilk, urn);

        // If CDP still has debt, it needs to be paid
        if (art > 0) {
            EndLike(end).skim(ilk, urn);
            (ink,) = vat.urns(ilk, urn);
        }
        // Approves the manager to transfer the position to proxy's address in the vat
        if (vat.can(address(this), address(manager)) == 0) {
            vat.hope(manager);
        }
        // Transfers position from CDP to the proxy address
        ManagerLike(manager).quit(cdp, address(this));
        // Frees the position and recovers the collateral in the vat registry
        EndLike(end).free(ilk);
    }

    // Public functions
    function freeETH(
        address manager,
        address ethJoin,
        address end,
        uint cdp
    ) public {
        uint wad = _free(manager, end, cdp);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(
        address manager,
        address gemJoin,
        address end,
        uint cdp
    ) public {
        uint amt = _free(manager, end, cdp) / 10 ** (18 - GemJoinLike(gemJoin).dec());
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function pack(
        address daiJoin,
        address end,
        uint wad
    ) public {
        daiJoin_join(daiJoin, address(this), wad);
        VatLike vat = DaiJoinLike(daiJoin).vat();
        // Approves the end to take out DAI from the proxy's balance in the vat
        if (vat.can(address(this), address(end)) == 0) {
            vat.hope(end);
        }
        EndLike(end).pack(wad);
    }

    function cashETH(
        address ethJoin,
        address end,
        bytes32 ilk,
        uint wad
    ) public {
        EndLike(end).cash(ilk, wad);
        uint wadC = mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function cashGem(
        address gemJoin,
        address end,
        bytes32 ilk,
        uint wad
    ) public {
        EndLike(end).cash(ilk, wad);
        // Exits token amount to the user's wallet as a token
        uint amt = mul(wad, EndLike(end).fix(ilk)) / RAY / 10 ** (18 - GemJoinLike(gemJoin).dec());
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }
}

contract DssProxyActionsDsr is Common {
    function join(
        address daiJoin,
        address pot,
        uint wad
    ) public {
        VatLike vat = DaiJoinLike(daiJoin).vat();
        // Executes drip to get the chi rate updated to rho == now, otherwise join will fail
        uint chi = PotLike(pot).drip();
        // Joins wad amount to the vat balance
        daiJoin_join(daiJoin, address(this), wad);
        // Approves the pot to take out DAI from the proxy's balance in the vat
        if (vat.can(address(this), address(pot)) == 0) {
            vat.hope(pot);
        }
        // Joins the pie value (equivalent to the DAI wad amount) in the pot
        PotLike(pot).join(mul(wad, RAY) / chi);
    }

    function exit(
        address daiJoin,
        address pot,
        uint wad
    ) public {
        VatLike vat = DaiJoinLike(daiJoin).vat();
        // Executes drip to count the savings accumulated until this moment
        uint chi = PotLike(pot).drip();
        // Calculates the pie value in the pot equivalent to the DAI wad amount
        uint pie = mul(wad, RAY) / chi;
        // Exits DAI from the pot
        PotLike(pot).exit(pie);
        // Checks the actual balance of DAI in the vat after the pot exit
        uint bal = DaiJoinLike(daiJoin).vat().dai(address(this));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (vat.can(address(this), address(daiJoin)) == 0) {
            vat.hope(daiJoin);
        }
        // It is necessary to check if due rounding the exact wad amount can be exited by the adapter.
        // Otherwise it will do the maximum DAI balance in the vat
        DaiJoinLike(daiJoin).exit(
            msg.sender,
            bal >= mul(wad, RAY) ? wad : bal / RAY
        );
    }

    function exitAll(
        address daiJoin,
        address pot
    ) public {
        VatLike vat = DaiJoinLike(daiJoin).vat();
        // Executes drip to count the savings accumulated until this moment
        uint chi = PotLike(pot).drip();
        // Gets the total pie belonging to the proxy address
        uint pie = PotLike(pot).pie(address(this));
        // Exits DAI from the pot
        PotLike(pot).exit(pie);
        // Allows adapter to access to proxy's DAI balance in the vat
        if (vat.can(address(this), address(daiJoin)) == 0) {
            vat.hope(daiJoin);
        }
        // Exits the DAI amount corresponding to the value of pie
        DaiJoinLike(daiJoin).exit(msg.sender, mul(chi, pie) / RAY);
    }
}
end of - TODO - implement more contracts */