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
import {Vow} from "dss/vow.sol";
import {Spotter} from "dss/spot.sol";
import {DaiJoin} from "dss/join.sol";
import {DSValue} from "ds-value/value.sol";
import {ManagedGemJoin} from "dss-gem-joins/join-managed.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";

contract Usr {

    bytes32 ilk;
    ManagedGemJoin adapter;
    CharterManagerImp manager;

    constructor(bytes32 ilk_, ManagedGemJoin adapter_, CharterManagerImp manager_) public {

        ilk = ilk_;
        adapter = adapter_;
        manager = manager_;
    }

    function approve(address coin, address usr) public {
        Token(coin).approve(usr, uint256(-1));
    }
    function join(address adapter_, address usr, uint256 wad) public {
        manager.join(address(adapter_), usr, wad);
    }
    function join(address usr, uint256 wad) public {
        manager.join(address(adapter), usr, wad);
    }
    function join(uint256 wad) public {
        manager.join(address(adapter), address(this), wad);
    }
    function exit(address adapter_, address usr, uint256 wad) public {
        manager.exit(address(adapter_), usr, wad);
    }
    function exit(address usr, uint256 wad) public {
        manager.exit(address(adapter), usr, wad);
    }
    function exit(uint256 wad) public {
        manager.exit(address(adapter), address(this), wad);
    }
    function move(address gemJoin, address usr, uint256 amt) public {
        manager.move(gemJoin, usr, amt);
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
    function hope(address usr) public {
        manager.hope(address(usr));
    }
    function nope(address usr) public {
        manager.nope(address(usr));
    }
    function frob(int256 dink, int256 dart) public {
        manager.frob(ilk, address(this), address(this), address(this), dink, dart);
    }
    function frob(bytes32 ilk_, address u, address v, address w, int256 dink, int256 dart) public {
        manager.frob(ilk_, u, v, w, dink, dart);
    }
    function frobDirect(bytes32 i, address u, address v, address w, int256 dink, int256 dart) public {
        VatLike(manager.vat()).frob(i, u, v, w, dink, dart);
    }
    function roll(bytes32 srcIlk, bytes32 dstIlk, address src, address dst, uint256 srcDart) public {
        manager.roll(srcIlk, dstIlk, src, dst, srcDart);
    }
    function flux(address src, address dst, uint256 wad) public {
        manager.flux(address(adapter), src, dst, wad);
    }
    function fluxDirect(address src, address dst, uint256 wad) public {
        VatLike(manager.vat()).flux(adapter.ilk(), src, dst, wad);
    }
    function quit() public {
        manager.quit(adapter.ilk(), address(this), address(this));
    }
    function quit(address u, address dst) public {
        manager.quit(adapter.ilk(), u, dst);
    }
    function joinDirect(address gemJoin, uint256 wad) public {
        GemJoin5(gemJoin).join(address(this), wad);
    }
    function exitDirect(address gemJoin, uint256 wad) public {
        GemJoin5(gemJoin).exit(address(this), wad);
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
    Spotter             spotter;
    DaiJoin             daiJoin;
    ManagedGemJoin      adapter;
    ManagedGemJoin      adapter2;
    CharterManagerImp   manager;

    address             self;
    bytes32             ilk  = "TOKEN-A";
    bytes32             ilk2 = "TOKEN-B";

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

        vat.file("Line", 100 * CEILING * 1e27);
        spotter = new Spotter(address(vat));

        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow), address(spotter))));
        manager = CharterManagerImp(address(base));

        // init ilk
        vat.init(ilk);
        vat.file(ilk, "line", CEILING * 1e27);
        vat.file(ilk, "spot", 1e27);

        spotter.file(ilk, "mat", 1.5 * 1e27);

        adapter = new ManagedGemJoin(address(vat), ilk, address(gem));
        vat.rely(address(adapter));

        adapter.rely(address(manager));
        adapter.deny(address(this));    // Only access should be through manager

        // init ilk2
        vat.init(ilk2);
        vat.file(ilk2, "line", CEILING * 1e27);
        vat.file(ilk2, "spot", 1e27);

        spotter.file(ilk2, "mat", 1.5 * 1e27);

        adapter2 = new ManagedGemJoin(address(vat), ilk2, address(gem));
        vat.rely(address(adapter2));

        adapter2.rely(address(manager));
        adapter2.deny(address(this));    // Only access should be through manager
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

    function init_ilk_ungate(bytes32 ilk_, uint256 Nib, uint256 Peace) public {
        manager.file(ilk_, "gate", 0);
        manager.file(ilk_, "Nib", Nib);
        manager.file(ilk_, "Peace", Peace);
    }

    function init_ilk_gate(bytes32 ilk_, address user, uint256 nib, uint256 peace, uint256 uline) public {
        manager.file(ilk_, "gate", 1);
        manager.file(ilk_, user, "nib", nib);
        manager.file(ilk_, user, "peace", peace);
        manager.file(ilk_, user, "uline", uline);
    }

    function init_user(bytes32 ilk_, ManagedGemJoin adapter_, uint256 cash) internal returns (Usr a, Usr b) {
        a = new Usr(ilk_, adapter_, manager);
        b = new Usr(ilk_, adapter_, manager);

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

    function test_hope_nope() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        assertEq(manager.can(address(b), address(a)), 0);
        b.hope(address(a));
        assertEq(manager.can(address(b), address(a)), 1);
        b.nope(address(a));
        assertEq(manager.can(address(b), address(a)), 0);
    }

    function test_join_exit_self() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
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
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);

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
        init_ilk_ungate(ilk, 0, 0);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
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
        init_ilk_ungate(ilk, NIB_ONE_PCT, 0);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
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

    function test_frob_ungate_above_Peace() public {
        init_ilk_ungate(ilk, 0, 3 * RAY);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 50 dai.
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

    function test_roll_to_same_ilk() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);
        init_ilk_gate(ilk, address(b), 0, 0, 200 * 1e45);
        manager.file(ilk, ilk, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);
        b.hope(address(a));
        a.roll(ilk, ilk, address(a), address(b), 5 * 1e18);

        (uint256 ink, uint256 art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 35 * 1e18);

        (ink, art) = vat.urns(ilk, b.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 45 * 1e18 + 1);
    }

    function test_roll_to_other_ilk() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        // set different rates per ilk
        vat.fold(ilk, address(vow), 0.05 * 1e27); // ilk rate is 1.05
        vat.fold(ilk2,address(vow), 0.02 * 1e27); // ilk2 rate is 1.02

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        b.hope(address(a));
        a.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);

        (uint256 ink, uint256 art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 35 * 1e18);

        (ink, art) = vat.urns(ilk2, b.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 45147058823529411765); // 40 + 5 * 1.05 / 1.02
    }

    function testFail_roll_to_other() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        // set different rates per ilk
        vat.fold(ilk, address(vow), 0.05 * 1e27); // ilk rate is 1.05
        vat.fold(ilk2,address(vow), 0.02 * 1e27); // ilk2 rate is 1.02

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        // a can to roll to b without its consent
        a.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);
    }

    function test_roll_from_other() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        // set different rates per ilk
        vat.fold(ilk, address(vow), 0.05 * 1e27); // ilk rate is 1.05
        vat.fold(ilk2,address(vow), 0.02 * 1e27); // ilk2 rate is 1.02

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        a.hope(address(b));
        b.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);

        (uint256 ink, uint256 art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 35 * 1e18);

        (ink, art) = vat.urns(ilk2, b.proxy());
        assertEq(ink, 100 * 1e18);
        assertEq(art, 45147058823529411765); // 40 + 5 * 1.05 / 1.02
    }

    function testFail_roll_from_other() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        // b not allowed to roll from a
        b.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);
    }

    function testFail_roll_from_non_gated() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_ungate(ilk, 0, 0);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        b.hope(address(a));
        a.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);
    }

    function testFail_roll_to_non_gated() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_ungate(ilk2, 0, 0);

        manager.file(ilk, ilk2, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        b.hope(address(a));
        a.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);
    }

    function testFail_non_rollable() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 200 * 1e45);

        (Usr b,) = init_user(ilk2, adapter2, 200 * 1e6);
        init_ilk_gate(ilk2, address(b), 0, 0, 200 * 1e45);

        a.join(100 * 1e6);
        b.join(address(adapter2), address(b), 100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);

        b.hope(address(a));
        // should fail as (ilk,ilk2) were not filed as rollable
        a.roll(ilk, ilk2, address(a), address(b), 5 * 1e18);
    }

    function testFail_roll_exceed_uline() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 45 * 1e45);
        init_ilk_gate(ilk, address(b), 0, 0, 45 * 1e45);
        manager.file(ilk, ilk, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);
        b.hope(address(a));

        // should fail since b's debt will be 50 dai and exceed the 45 uline
        a.roll(ilk, ilk, address(a), address(b), 10 * 1e18);
    }

    function testFail_roll_to_below_peace() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 100 * 1e45);
        init_ilk_gate(ilk, address(b), 0, 3 * RAY, 100 * 1e45);
        manager.file(ilk, ilk, address(a), address(b), "rollable", 1);

        a.join(100 * 1e6);
        b.join(100 * 1e6);

        a.frob(100 * 1e18, 40 * 1e18);
        b.frob(100 * 1e18, 40 * 1e18);
        b.hope(address(a));

        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 50 dai.
        a.roll(ilk, ilk, address(a), address(b), 11 * 1e18);
    }

    function test_exit() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);

        a.join(200 * 1e6);
        assertEq(a.gems(), 200 * 1e18);
        assertEq(gem.balanceOf(address(a)), 0);

        // check exit of unlocked gems does not affect the vault and does not prevent increasing debt
        a.exit(200 * 1e6);
        assertEq(a.gems(), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
    }

    function test_exit_to_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);

        a.join(200 * 1e6);
        assertEq(a.gems(), 200 * 1e18);
        assertEq(gem.balanceOf(address(a)), 0);

        assertEq(gem.balanceOf(address(b)), 200 * 1e6);
        a.exit(address(b), 200 * 1e6);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(b)), 400 * 1e6);
    }

    function test_exit_maintains_peace() public {
        init_ilk_ungate(ilk, 0, 3 * RAY);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(200 * 1e6);
        assertEq(a.gems(), 200 * 1e18);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 50 dai.
        a.frob(100 * 1e18, 45 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 45 * 1e18);
        assertEq(a.dai(), 45 * 1e45);
        assertEq(a.gems(), 100 * 1e18);

        // check exit of unlocked gems does not affect the vault and does not prevent increasing debt
        a.exit(100 * 1e6);
        (ink, art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 45 * 1e18);
        assertEq(a.dai(), 45 * 1e45);
        assertEq(a.gems(), 0);

        a.frob(0, 5 * 1e18);
        (ink, art) = a.urn();
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

    function test_move() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        cheat_get_dai(address(this), 2 * 1e18);
        dai.approve(address(daiJoin), 2 * 1e18);

        manager.getOrCreateProxy(address(a));
        daiJoin.join(a.proxy(), 2 * 1e18);
        assertEq(vat.dai(a.proxy()), 2 * 1e45);

        a.move(address(a), address(this), 2 * 1e45);
        assertEq(vat.dai(a.proxy()), 0);
        assertEq(vat.dai(address(this)), 2 * 1e45);
    }

    function test_move_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        cheat_get_dai(address(this), 2 * 1e18);
        dai.approve(address(daiJoin), 2 * 1e18);

        manager.getOrCreateProxy(address(a));
        daiJoin.join(a.proxy(), 2 * 1e18);
        assertEq(vat.dai(a.proxy()), 2 * 1e45);

        a.hope(address(b));
        b.move(address(a), address(this), 2 * 1e45);
        assertEq(vat.dai(a.proxy()), 0);
        assertEq(vat.dai(address(this)), 2 * 1e45);
    }

    function testFail_move_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        cheat_get_dai(address(this), 2 * 1e18);
        dai.approve(address(daiJoin), 2 * 1e18);

        manager.getOrCreateProxy(address(a));
        daiJoin.join(a.proxy(), 2 * 1e18);
        assertEq(vat.dai(a.proxy()), 2 * 1e45);

        // b is not authorized to to move dai from a's proxy
        b.move(address(a), address(this), 2 * 1e45);
    }

    function testFail_frob_ungate_below_Peace() public {
        init_ilk_ungate(ilk, 0, 3 * RAY);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 50 dai.
        a.frob(100 * 1e18, 51 * 1e18);
    }

    function testFail_frob_ungate_withdraw_below_Peace() public {
        init_ilk_ungate(ilk, 0, 3 * RAY);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 50 dai.
        a.frob(100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);

        // should not be able to withdraw collateral and go below min cr
        a.frob(-1 * 1e18, 0);
    }

    function test_frob_gate() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 50 * 1e45);

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

    function test_migration() public {
        (Usr old,) = init_user(ilk, adapter, 200 * 1e6);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);

        // setup old (different) ilk with the same gem to migrate out from
        bytes32 oldIlk = "TOKEN-C";
        vat.init(oldIlk);
        vat.file(oldIlk, "line", CEILING * 1e27);
        vat.file(oldIlk, "spot", 1e27);

        GemJoin5 oldAdapter = new GemJoin5(address(vat), oldIlk, address(gem));
        vat.rely(address(oldAdapter));

        // setup old vault
        old.approve(address(gem), address(oldAdapter));
        old.joinDirect(address(oldAdapter), 60 * 1e6);
        old.frobDirect(oldIlk, address(old), address(old), address(old), 60 * 1e18, 40 * 1e18);

        (uint256 ink, uint256 art) = vat.urns(oldIlk, address(old));
        assertEq(ink, 60 * 1e18);
        assertEq(art, 40 * 1e18);
        assertEq(old.dai(), 40 * 1e45);
        assertEq(old.gems(), 0);

        // set different rates per ilk
        vat.fold(oldIlk, address(vow), 0.05 * 1e27); // old rate is 1.05
        vat.fold(ilk,    address(vow), 0.02 * 1e27); // new rate is 1.02

        uint256 vowSinBefore = vat.sin(address(vow));

        // perform privileged migration sequence
        (, uint256 oldRate,,,) = vat.ilks(oldIlk);
        (, uint256 rate,,,) = vat.ilks(ilk);

        int256  dart = int256(mul(oldRate, art) / rate);
        int256  dink = int256(ink);
        uint256 dec = Token(gem).decimals();
        uint256 gemAmt = ink / (10 ** (18 - dec));

        // Note: In a spell obviously we'd drip both ilks before running the logic as well,
        // so that all parties get a fair treatment regarding fees.
        vat.grab(oldIlk, address(old), address(this), address(vow), -int256(ink), -int256(art));
        oldAdapter.exit(address(this), gemAmt);
        Token(gem).approve(address(manager), gemAmt);
        manager.join(address(adapter), address(a), gemAmt);
        vat.grab(ilk, a.proxy(), a.proxy(), address(vow), dink, dart);

        // make sure new position is as expected under the manager's ilk
        (ink, art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 60 * 1e18);
        assertEq(art, 41176470588235294117); // 40 * (1.05 / 1.02) * 1e18
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 0);

        // due to precision imperfection vice is not zeroed back, but diff is negligible
        assert((vat.sin(address(vow)) - vowSinBefore) < 1e30);
        assert(vat.vice() < 1e30);

        // no sin is brought upon any other address than the vow
        assertEq(vat.sin(address(this)), 0);
    }

    function test_frob_gate_nib() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 2 * NIB_ONE_PCT, 0, 50 * 1e45);

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

    function test_frob_gate_above_peace() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 2 * RAY, 100 * 1e45);

        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 75 dai.
        a.frob(100 * 1e18, 75 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 75 * 1e18);
        assertEq(a.dai(), 75 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(vat.dai(address(vow)), 0);
        a.frob(-100 * 1e18, -75 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function testFail_frob_gate_below_peace() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 2 * RAY, 100 * 1e45);

        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 75 dai.
        a.frob(100 * 1e18, 76 * 1e18);
    }

    function testFail_frob_gate_withdraw_below_peace() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 2 * RAY, 100 * 1e45);

        a.join(100 * 1e6);
        // (mat = 1.5, spot = 1) => price = 1.5, 100 col is worth 150 dai => can draw up to 75 dai.
        a.frob(100 * 1e18, 75 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 75 * 1e18);
        assertEq(a.dai(), 75 * 1e45);
        assertEq(a.gems(), 0);

        // should not be able to withdraw collateral and go below min cr
        a.frob(-1 * 1e18, 0);
    }

    function testFail_frob_undelegated_manager() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 50 * 1e45);
        a.nope(address(vat), address(manager));

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);

        // loan repayment should fail as its destination did not delegate the manager
        a.frob(-100 * 1e18, -50 * 1e18);
    }

    function testFail_frob_gate_uline_exceeded() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 50 * 1e45);

        a.join(100 * 1e6);
        a.frob(100 * 1e18, 60 * 1e18);
    }

    function testFail_frob_gate_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 50 * 1e45);

        b.join(100 * 1e6);
        b.frob(100 * 1e18, 50 * 1e18);
    }

    function test_drip_withdraw() public {
        init_ilk_ungate(ilk, 10 * NIB_ONE_PCT, 0);
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);

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
        a.frob(-10 * 1e18, -15 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 10 * 1e18);
        assertEq(art, 5 * 1e18);
        assertEq(a.gems(), 10 * 1e18);
        // -15 * 1e18 should be taking 15.3 DAI (15 + 2%) from the current 18 DAI balance.
        assertEq(a.dai(), 2.7 * 1e45);

        // force extra dai balance
        cheat_get_dai(address(this), uint256(100 * 1e18));
        dai.approve(address(daiJoin), 100 * 1e18);
        daiJoin.join(address(a), 100 * 1e18);

        // repay remaining debt, withdraw collateral
        a.frob(-10 * 1e18, -5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.gems(), 20 * 1e18);
    }

    function test_debt_ceiling_removal() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        init_ilk_gate(ilk, address(a), 0, 0, 50 * 1e45);

        a.join(20 * 1e6);
        a.frob(20 * 1e18, 20 * 1e18);
        (uint256 ink, uint256 art) = a.urn();
        assertEq(ink, 20 * 1e18);
        assertEq(art, 20 * 1e18);
        assertEq(a.dai(), 20 * 1e45);
        assertEq(a.gems(), 0);

        // remove the debt ceiling entirely
        manager.file(ilk, address(a), "uline", 0);

        // partial repay - frob out some of the funds
        a.frob(-10 * 1e18, -15 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 10 * 1e18);
        assertEq(art, 5 * 1e18);
        assertEq(a.gems(), 10 * 1e18);
        assertEq(a.dai(), 5* 1e45);

        // repay remaining debt, withdraw collateral
        a.frob(-10 * 1e18, -5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.gems(), 20 * 1e18);
    }

    // Non-msg.sender frobs should be disallowed for now
    function testFail_frob1() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        a.frob(ilk, address(this), address(a), address(a), 100 * 1e18, 50 * 1e18);
    }
    function testFail_frob2() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        a.frob(ilk, address(a), address(this), address(a), 100 * 1e18, 50 * 1e18);
    }

    function test_frob_other_u() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
        assertEq(gem.balanceOf(address(b)), 200 * 1e6);
        a.join(address(b), 100 * 1e6);
        assertEq(gem.balanceOf(address(a)), 100 * 1e6);
        assertEq(b.gems(), 100 * 1e18);
        b.hope(address(a));
        a.frob(ilk, address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
        assertEq(b.gems(), 0);
        (uint256 ink, uint256 art) = b.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(a.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);
        a.frob(ilk, address(b), address(b), address(a), -100 * 1e18, -50 * 1e18);
        (ink, art) = b.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(b.gems(), 100 * 1e18);
    }

    function testFail_frob_other_u_1() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(address(b), 100 * 1e6);
        a.frob(ilk, address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
    }

    function testFail_frob_other_u_2() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(address(b), 100 * 1e6);
        b.hope(address(a));
        b.nope(address(a));
        a.frob(ilk, address(b), address(b), address(a), 100 * 1e18, 50 * 1e18);
    }

    function test_frob_other_w() public {
        init_ilk_ungate(ilk, 0, 0);
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        b.join(100 * 1e6);
        b.hope(address(a));
        a.frob(ilk, address(b), address(b), address(b), 100 * 1e18, 50 * 1e18);
        (uint256 ink, uint256 art) = b.urn();
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(b.dai(), 50 * 1e45);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 0);
        a.frob(ilk, address(b), address(b), address(b), -100 * 1e18, -50 * 1e18);
        (ink, art) = b.urn();
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(a.dai(), 0);
        assertEq(b.dai(), 0);
        assertEq(b.gems(), 100 * 1e18);
    }

    function testFail_frob_other_w() public {
        init_ilk_ungate(ilk, 0, 0);
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        // a can not frob to/from b without permission
        a.frob(ilk, address(a), address(a), address(b), 100 * 1e18, 50 * 1e18);
    }

    function test_flux_to_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        assertEq(a.gems(), 100 * 1e18);
        a.flux(address(a), address(a), 100 * 1e18);
        assertEq(a.gems(), 100 * 1e18);
        a.exit(100 * 1e6);
        assertEq(a.gems(), 0);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
    }

    function test_flux_from_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        assertEq(a.gems(), 100 * 1e18);
        a.hope(address(b));
        b.flux(address(a), address(b), 100 * 1e18);
        assertEq(a.gems(), 0);
        assertEq(b.gems(), 100 * 1e18);
        b.exit(100 * 1e6);
        assertEq(b.gems(), 0);
        assertEq(gem.balanceOf(address(b)), 300 * 1e6);
    }

    function testFail_flux_from_other1() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        b.flux(address(a), address(b), 100 * 1e18);
    }

    function testFail_flux_from_other2() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        a.hope(address(b));
        a.nope(address(b));
        b.flux(address(a), address(b), 100 * 1e18);
    }

    function testFail_quit() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(100 * 1e6);
        a.frob(100 * 1e18, 50 * 1e18);
        a.quit();       // Attempt to unbox the urn (should fail when vat is live)
    }
    function test_quit() public {
        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
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
        a.frobDirect(ilk, address(a), address(a), address(a), -100 * 1e18, -50 * 1e18);
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

    function test_quit_from_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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
        a.hope(address(b));
        b.quit(address(a), address(a));
        (ink, art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns(ilk, address(a));
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(vat.gem(ilk, address(a)), 0);
    }

    function testFail_quit_from_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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
        // b is not allowed to quit a
        b.quit(address(a), address(a));
    }

    function test_quit_to_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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
        b.hope(address(a));
        a.quit(address(a), address(b));
        (ink, art) = vat.urns(ilk, a.proxy());
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns(ilk, b.proxy());
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns(ilk, address(b));
        assertEq(ink, 100 * 1e18);
        assertEq(art, 50 * 1e18);
        assertEq(vat.gem(ilk, address(a)), 0);
        assertEq(vat.gem(ilk, address(b)), 0);
    }

    function testFail_quit_to_other() public {
        (Usr a, Usr b) = init_user(ilk, adapter, 200 * 1e6);
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

        // quit to an unauthorized dst should fail
        a.quit(address(a), address(b));
    }

    // Make sure we can't call most functions on the adapter directly
    function testFail_direct_join() public {
        adapter.join(address(this), 0);
    }
    function testFail_direct_exit() public {
        adapter.exit(address(this), address(this), 0);
    }

    function test_implementation_upgrade() public {

        (Usr a,) = init_user(ilk, adapter, 200 * 1e6);
        a.join(10 * 1e6);
        assertEq(gem.balanceOf(address(a)), 190 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 10 * 1e6);
        assertEq(a.gems(), 10 * 1e18);

        address impl = CharterManager(address(manager)).implementation();
        // Replace implementation
        CharterManager(address(manager)).setImplementation(
            address(new CharterManagerImp(address(vat), address(vow), address(spotter)))
        );
        assertTrue(impl != CharterManager(address(manager)).implementation());

        a.exit(10 * 1e6);
        assertEq(gem.balanceOf(address(a)), 200 * 1e6);
        assertEq(gem.balanceOf(address(adapter)), 0);
        assertEq(a.gems(), 0);
    }
}
