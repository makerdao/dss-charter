// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
//
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

import "./TestBase.sol";
import "src/CharterManager.sol";

import {Vat} from "dss/vat.sol";
import {Vow} from 'dss/vow.sol';
import {DaiJoin} from 'dss/join.sol';
import {DSValue} from 'ds-value/value.sol';
import {ManagedGemJoin} from "dss-gem-joins/join-managed.sol";

contract Usr {

    ManagedGemJoin adapter;
    CharterManagerImp manager;

    constructor(ManagedGemJoin adapter_, CharterManagerImp manager_) public {
        adapter = adapter_;
        manager = manager_;
    }

    function approve(address coin, address usr) public {
        Token(coin).approve(usr, uint256(-1));
    }
    function join(address usr, uint256 wad) public {
        manager.join(address(adapter), usr, wad);
    }
    function join(uint256 wad) public {
        manager.join(address(adapter), address(this), wad);
    }
    function exit(address usr, uint256 wad) public {
        manager.exit(address(adapter), usr, wad);
    }
    function exit(uint256 wad) public {
        manager.exit(address(adapter), address(this), wad);
    }
    function proxy() public view returns (address) {
        return manager.proxy(address(this));
    }
    function gems() public view returns (uint256) {
        return Vat(address(adapter.vat())).gem(adapter.ilk(), proxy());
    }
    function urn() public view returns (uint256, uint256) {
        return Vat(address(adapter.vat())).urns(adapter.ilk(), proxy());
    }
    function dai() public view returns (uint256) {
        return Vat(address(adapter.vat())).dai(address(this));
    }
    function allow(address usr) public {
        manager.allow(address(usr));
    }
    function disallow(address usr) public {
        manager.disallow(address(usr));
    }
    function frob(int256 dink, int256 dart) public {
        manager.frob(address(adapter), address(this), address(this), address(this), dink, dart);
    }
    function frob(address u, address v, address w, int256 dink, int256 dart) public {
        manager.frob(address(adapter), u, v, w, dink, dart);
    }
    function frobDirect(address u, address v, address w, int256 dink, int256 dart) public {
        VatLike(manager.vat()).frob(adapter.ilk(), u, v, w, dink, dart);
    }
    function flux(address src, address dst, uint256 wad) public {
        manager.flux(address(adapter), src, dst, wad);
    }
    function fluxDirect(address src, address dst, uint256 wad) public {
        VatLike(manager.vat()).flux(adapter.ilk(), src, dst, wad);
    }
    function quit() public {
        manager.quit(adapter.ilk(), address(this));
    }
    function quit(address dst) public {
        manager.quit(adapter.ilk(), dst);
    }
    function hope(address vat, address usr) public {
        Vat(vat).hope(usr);
    }
    function nope(address vat, address usr) public {
        Vat(vat).nope(usr);
    }

    function try_call(address addr, bytes calldata data) external returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }
    function can_call(address addr, bytes memory data) internal returns (bool) {
        (bool ok, bytes memory success) = address(this).call(
            abi.encodeWithSignature(
                "try_call(address,bytes)"
            , addr
            , data
            ));
        ok = abi.decode(success, (bool));
        if (ok) return true;
    }
    function can_exit(address usr, uint256 val) public returns (bool) {
        bytes memory call = abi.encodeWithSignature
        ("exit(address,address,uint256)", address(adapter), usr, val);
        return can_call(address(manager), call);
    }
}

contract CharterManagerTest is TestBase {

    Token               gem;
    Token               dai;
    Vat                 vat;
    Vow                 vow;
    DaiJoin             daiJoin;
    ManagedGemJoin      adapter;
    CharterManagerImp   manager;

    address             self;
    bytes32             ilk = "TOKEN-A";

    uint256 constant NIB_ONE_PCT = 1.0 * 1e16;
    uint256 constant CEILING     = 100 * 1e18;

    function setUp() public virtual {
        self = address(this);
        gem = new Token(6, 1000 * 1e6);

        // standard Vat setup
        vat = new Vat();
        vow = new Vow(address(vat), address(0), address(0));

        dai = new Token(18, CEILING);
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));

        vat.init(ilk);
        vat.file("Line", 100 * CEILING * 1e27);
        vat.file(ilk, "line", CEILING * 1e27);
        vat.file(ilk, "spot", 1e36);

        // adapter and manager setup
        adapter = new ManagedGemJoin(address(vat), ilk, address(gem));
        vat.rely(address(adapter));

        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow))));
        manager = CharterManagerImp(address(base));

        adapter.rely(address(manager));
        adapter.deny(address(this));    // Only access should be through manager
    }

    function cheat_get_dai(address rec, uint256 wad) public {
        hevm.store(
            address(dai),
            keccak256(abi.encode(rec, uint256(3))),
            bytes32(wad)
        );
        hevm.store(
            address(dai),
            bytes32(uint256(2)),
            bytes32(wad)
        );
        hevm.store(
            address(vat),
            keccak256(abi.encode(address(daiJoin), uint256(5))),
            bytes32(wad * RAY)
        );
    }

    function cheat_uncage() public {
        hevm.store(
            address(vat),
            bytes32(uint256(10)),
            bytes32(uint256(1))
        );
    }

    function init_ilk_ungate(uint256 Nib) public {
        manager.file(ilk, "gate", 0);
        manager.file(ilk, "Nib", Nib);
    }

    function init_ilk_gate(address user, uint256 nib, uint256 uline) public {
        manager.file(ilk, "gate", 1);
        manager.file(ilk, user, "nib", nib);
        manager.file(ilk, user, "uline", uline);
    }

    function init_user() internal returns (Usr a, Usr b) {
        return init_user(200 * 1e6);
    }
    function init_user(uint256 cash) internal returns (Usr a, Usr b) {
        a = new Usr(adapter, manager);
        b = new Usr(adapter, manager);

        gem.transfer(address(a), cash);
        gem.transfer(address(b), cash);

        a.approve(address(gem), address(manager));
        b.approve(address(gem), address(manager));

        a.hope(address(vat), address(manager));
        b.hope(address(vat), address(manager));
    }

    function test_make_proxy() public {
        assertEq(manager.proxy(address(this)), address(0));
        manager.join(address(adapter), address(this), 0);
        assertTrue(manager.proxy(address(this)) != address(0));
    }

    function test_allow_disallow() public {
        (Usr a, Usr b) = init_user();
        assertEq(manager.can(address(b), address(a)), 0);
        b.allow(address(a));
        assertEq(manager.can(address(b), address(a)), 1);
        b.disallow(address(a));
        assertEq(manager.can(address(b), address(a)), 0);
    }

    function test_join_exit_self() public {
        (Usr a,) = init_user();
        a.join(10 * 1e6);
        assertEq(gem.balanceOf(address(a)), 190 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 10 * 1e6);
        assertEq(a.gems(), 10 * 1e18);
        a.exit(10 * 1e6);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 0);
        assertEq(a.gems(), 0);
    }

    function test_join_other1() public {
        (Usr a, Usr b) = init_user();
        a.join(10 * 1e6);
        assertEq(gem.balanceOf(address(a)), 190 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 10 * 1e6);
        assertEq(a.gems(), 10 * 1e18);
        b.join(address(a), 20 * 1e6);
        assertEq(gem.balanceOf(address(a)), 190 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 30 * 1e6);
        assertEq(a.gems(), 30 * 1e18);
    }

    function test_join_other2() public {
        (Usr a, Usr b) = init_user();

        assertEq(gem.balanceOf(address(a)), 200e6);
        assertEq(gem.balanceOf(address(b)), 200e6);

        // User A sends some gems to User B
        a.join(address(b), 100e6);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 100e18);
        assertEq(gem.balanceOf(address(a)), 100e6);
        assertEq(gem.balanceOf(address(b)), 200e6);

        // B withdraws to A
        b.exit(address(a), 100e6);
        assertEq(gem.balanceOf(address(a)), 200e6);
        assertEq(gem.balanceOf(address(b)), 200e6);
    }

    function test_frob_ungate() public {
        init_ilk_ungate(0);
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);
        a.frob(-100 * 1e18, -50 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function test_frob_ungate_Nib() public {
        init_ilk_ungate(NIB_ONE_PCT);
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 49.5 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(vat.dai(address(vow)), 0.5 * 1e45);

        // frob out some of the funds
        a.frob(-90 * 1e18, -49.5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 10 * 1e18);
        assertEq(art, 0.5 * 1e18);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 90 * 1e18);

        // force extra dai balance to cover for paid origination fee
        cheat_get_dai(address(this), uint256(0.5 * 1e18));
        dai.approve(address(daiJoin), 0.5 * 1e18);
        daiJoin.join(address(a), 0.5 * 1e18);
        assertEq(a.dai(), 0.5 * 1e45);

        // repay remaining debt
        a.frob(-10 * 1e18, -0.5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function test_frob_gate() public {
        (Usr a,) = init_user();
        init_ilk_gate(address(a), 0, 50 * 1e45);

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(vat.dai(address(vow)), 0);
        a.frob(-100 * 1e18, -50 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function test_frob_gate_nib() public {
        (Usr a,) = init_user();
        init_ilk_gate(address(a), 2 * NIB_ONE_PCT, 50 * 1e45);

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 49 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(vat.dai(address(vow)), 1 * 1e45);

        // frob out some of the funds
        a.frob(-90 * 1e18, -49 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 10 * 1e18);
        assertEq(art, 1 * 1e18);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 90 * 1e18);

        // force extra dai balance to cover for paid origination fee
        cheat_get_dai(address(this), uint256(1 * 1e18));
        dai.approve(address(daiJoin), 1 * 1e18);
        daiJoin.join(address(a), 1 * 1e18);
        assertEq(a.dai(), 1 * 1e45);

        // repay remaining debt
        a.frob(-10 * 1e18, -1 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function testFail_frob_undelegated_manager() public {
        (Usr a,) = init_user();
        init_ilk_gate(address(a), 0, 50 * 1e45);
        a.nope(address(vat), address(manager));

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);

        // loan repayment should fail as its destination did not delegate the manager
        a.frob(-100 * 1e18, -50 * 1e18);
    }

    function testFail_frob_gate_uline_exceeded() public {
        (Usr a,) = init_user();
        init_ilk_gate(address(a), 0, 50 * 1e45);

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 60 * 1e18);
    }

    function testFail_frob_gate_other() public {
        (Usr a, Usr b) = init_user();
        init_ilk_gate(address(a), 0, 50 * 1e45);

        b.join(100 * 1e6);
        b.frob(100 * 1e18, 50 * 1e18);
    }

    function test_drip_withdraw() public {
        init_ilk_ungate(10 * NIB_ONE_PCT);
        (Usr a,) = init_user();

        a.join(20 * 1e6);
        a.frob(20 * 1e18, 20 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 20 * 1e18);
        assertEq(art, 20 * 1e18);
        assertEq(a.dai(), 18 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(vat.dai(address(vow)), 2 * 1e45);

        // increase rate by 2%
        vat.fold(ilk, address(vow), 0.02 * 1e27);

        // frob out some of the funds
        a.frob(-15 * 1e18, -15 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 5 * 1e18);
        assertEq(art, 5 * 1e18);
        assertEq(a.gems(), 15 * 1e18);
        // -15 * 1e18 should be taking 15.3 DAI (15 + 2%) from the current 18 DAI balance.
        assertEq(a.dai(), 2.7 * 1e45);

        // force extra dai balance
        cheat_get_dai(address(this), uint256(100 * 1e18));
        dai.approve(address(daiJoin), 100 * 1e18);
        daiJoin.join(address(a), 100 * 1e18);

        // repay remaining debt, withdraw collateral
        a.frob(-5 * 1e18, -5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.gems(), 20 * 1e18);
    }

    // Non-msg.sender frobs should be disallowed for now
    function testFail_frob1() public {
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(address(this), address(a), address(a), 100 * 1e18, 50 * 1e18);
    }
    function testFail_frob2() public {
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(address(a), address(this), address(a), 100 * 1e18, 50 * 1e18);
    }
    function testFail_frob3() public {
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(address(a), address(a), address(this), 100 * 1e18, 50 * 1e18);
    }

    function test_frob_other() public {
        (Usr a, Usr b) = init_user();
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
        assertEq(gem.balanceOf(address(b)), 200 * 1e6);
        a.join(address(b), 100 * 1e6);
        assertEq(gem.balanceOf(address(a)), 100 * 1e6);
        assertEq(b.gems(), 100 * 1e18);
        b.allow(address(a));
        a.frob(address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
        assertEq(b.gems(), 0);
        (uint256 ink, uint256 art) = b.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);
        a.frob(address(b), address(b), address(a), -100 * 1e18, -50 * 1e18);
        (ink, art) = b.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(b.gems(), 100 * 1e18);
    }

    function testFail_frob_other1() public {
        (Usr a, Usr b) = init_user();
        a.join(address(b), 100 * 1e6);
        a.frob(address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
    }

    function testFail_frob_other2() public {
        (Usr a, Usr b) = init_user();
        a.join(address(b), 100 * 1e6);
        b.allow(address(a));
        b.disallow(address(a));
        a.frob(address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
    }

    function test_flux_to_other() public {
        (Usr a, Usr b) = init_user();
        a.join(100 * 1e6);
        assertEq(a.gems(), 100 * 1e18);
        a.flux(address(a), address(b), 100 * 1e18);
        assertEq(b.gems(), 100 * 1e18);
        b.exit(100 * 1e6);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(b)), 300 * 1e6);
    }
    function test_flux_yourself() public {
        // Flux to yourself should be a no-op
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        assertEq(a.gems(), 100 * 1e18);
        a.flux(address(a), address(a), 100 * 1e18);
        assertEq(a.gems(), 100 * 1e18);
        a.exit(100 * 1e6);
        assertEq(a.gems(), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
    }

    function test_flux_from_other() public {
        (Usr a, Usr b) = init_user();
        a.join(100 * 1e6);
        assertEq(a.gems(), 100 * 1e18);
        a.allow(address(b));
        b.flux(address(a), address(b), 100 * 1e18);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 100 * 1e18);
        b.exit(100 * 1e6);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(b)), 300 * 1e6);
    }

    function testFail_flux_from_other1() public {
        (Usr a, Usr b) = init_user();
        a.join(100 * 1e6);
        b.flux(address(a), address(b), 100 * 1e18);
    }

    function testFail_flux_from_other2() public {
        (Usr a, Usr b) = init_user();
        a.join(100 * 1e6);
        a.allow(address(b));
        a.disallow(address(b));
        b.flux(address(a), address(b), 100 * 1e18);
    }

    function testFail_quit() public {
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        a.quit();       // Attempt to unbox the urn (should fail when vat is live)
    }
    function test_quit() public {
        (Usr a,) = init_user();
        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        vat.cage();
        (uint256 ink, uint256 art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        (ink, art) = vat.urns(ilk, address(a));
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(vat.gem(ilk, address(a)), 0);
        a.quit();
        (ink, art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns(ilk, address(a));
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(vat.gem(ilk, address(a)), 0);

        // Can now interact directly with the vat to unencumber the collateral.

        // frobDirect used as shortcut instead of end.free which would grab the ink after vat.cage.
        cheat_uncage();
        a.frobDirect(address(a), address(a), address(a), -100 * 1e18, -50 * 1e18);
        vat.cage();

        assertEq(vat.gem(ilk, address(a)), 100 * 1e18);
        (ink, art) = vat.urns(ilk, address(a));
        assertEq(ink, 0);
        assertEq(art, 0);

        // Need to move the gems back to the proxy to exit through the crop join

        a.fluxDirect(address(a), a.proxy(), 100 * 1e18);
        assertEq(vat.gem(ilk, address(a)), 0);
        assertEq(vat.gem(ilk, a.proxy()), 100 * 1e18);
        a.exit(100 * 1e6);
        assertEq(vat.gem(ilk, a.proxy()), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
    }
    // Make sure we can't call most functions on the adapter directly
    function testFail_direct_join() public {
        adapter.join(address(this), 0);
    }
    function testFail_direct_exit() public {
        adapter.exit(address(this), address(this), 0);
    }
}
