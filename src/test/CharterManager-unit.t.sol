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
import {ManagedGemJoin} from "lib/dss-gem-joins/src/join-managed.sol";
import "src/CharterManager.sol";

contract MockVat {
    struct Urn {
        uint256 ink;   // Locked Collateral  [wad]
        uint256 art;   // Normalised Debt    [wad]
    }
    struct Ilk {
        uint256 Art;   // Total Normalised Debt     [wad]
        uint256 rate;  // Accumulated Rates         [ray]
        uint256 spot;  // Price with Safety Margin  [ray]
        uint256 line;  // Debt Ceiling              [rad]
        uint256 dust;  // Urn Debt Floor            [rad]
    }
    mapping (bytes32 => Ilk) public ilks;
    mapping (bytes32 => mapping (address => uint256)) public gem;
    mapping (bytes32 => mapping (address => Urn)) public urns;
    mapping (address => uint256) public dai;
    uint256 public live = 1;

    function mockIlk(bytes32 ilk, uint256 _rate) external {
        ilks[ilk].rate = _rate;
    }
    function add(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x + uint256(y);
        require(y >= 0 || z <= x, "vat/add-fail");
        require(y <= 0 || z >= x, "vat/add-fail");
    }
    function sub(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x - uint256(y);
        require(y <= 0 || z <= x, "vat/sub-fail");
        require(y >= 0 || z >= x, "vat/sub-fail");
    }
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "vat/add-fail");
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "vat/sub-fail");
    }
    function slip(bytes32 ilk, address usr, int256 wad) external {
        gem[ilk][usr] = add(gem[ilk][usr], wad);
    }
    function frob(bytes32 ilk, address u, address v, address w, int256 dink, int256 dart) external {
        Urn storage urn = urns[ilk][u];
        urn.ink = add(urn.ink, dink);
        urn.art = add(urn.art, dart);
        gem[ilk][v] = sub(gem[ilk][v], dink);
        dai[w] = add(dai[w], dart * 10**27);
    }
    function fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) external {
        Urn storage u = urns[ilk][src];
        Urn storage v = urns[ilk][dst];

        u.ink = sub(u.ink, dink);
        u.art = sub(u.art, dart);
        v.ink = add(v.ink, dink);
        v.art = add(v.art, dart);
    }
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external {
        gem[ilk][src] = sub(gem[ilk][src], wad);
        gem[ilk][dst] = add(gem[ilk][dst], wad);
    }
    function move(address src, address dst, uint256 rad) external {
        dai[src] = sub(dai[src], rad);
        dai[dst] = add(dai[dst], rad);
    }
    function hope(address usr) external {}
    function cage() external {
        live = 0;
    }
}

contract MockVow {
    MockVat vat;

    constructor(MockVat vat_) public {
        vat = vat_;
    }

    function dai() public view returns (uint256) {
        return vat.dai(address(this));
    }
}

contract Usr {

    ManagedGemJoin adapter;
    CharterManagerImp manager;
    MockVat vat;

    constructor(ManagedGemJoin adapter_, CharterManagerImp manager_, MockVat vat_) public {
        adapter = adapter_;
        manager = manager_;
        vat = vat_;
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
        return CharterManager(address(manager)).proxy(address(this));
    }
    function gems() public view returns (uint256) {
        return vat.gem(adapter.ilk(), proxy());
    }
    function urn() public view returns (uint256, uint256) {
        return vat.urns(adapter.ilk(), proxy());
    }
    function dai() public view returns (uint256) {
        return vat.dai(address(this));
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
    MockVat             vat;
    MockVow             vow;
    address             self;
    bytes32             ilk = "TOKEN-A";
    ManagedGemJoin      adapter;
    CharterManagerImp   manager;

    uint256 constant NIB_ONE_PCT = 1.0 * 1e16;

    function setUp() public virtual {
        self = address(this);
        gem = new Token(6, 1000 * 1e6);
        vat = new MockVat();
        vow = new MockVow(vat);
        adapter = new ManagedGemJoin(address(vat), ilk, address(gem));
        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow))));
        manager = CharterManagerImp(address(base));

        adapter.rely(address(manager));
        adapter.deny(address(this));    // Only access should be through manager
    }

    function init_ilk_ungate(uint256 Nib) public {
        vat.mockIlk(ilk, 1e27);
        manager.file(ilk, "gate", false);
        manager.file(ilk, "Nib", Nib);
    }

    function init_ilk_gate(address user, uint256 nib, uint256 line) public {
        vat.mockIlk(ilk, 1e27);
        manager.file(ilk, "gate", true);
        manager.file(ilk, user, "nib", nib);
        manager.file(ilk, user, "line", line);
    }

    function init_user() internal returns (Usr a, Usr b) {
        return init_user(200 * 1e6);
    }
    function init_user(uint256 cash) internal returns (Usr a, Usr b) {
        a = new Usr(adapter, manager, vat);
        b = new Usr(adapter, manager, vat);

        gem.transfer(address(a), cash);
        gem.transfer(address(b), cash);

        a.approve(address(gem), address(manager));
        b.approve(address(gem), address(manager));
    }

    function test_make_proxy() public {
        assertEq(CharterManager(address(manager)).proxy(address(this)), address(0));
        manager.join(address(adapter), address(this), 0);
        assertTrue(CharterManager(address(manager)).proxy(address(this)) != address(0));
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
        assertEq(vow.dai(), 0.5 * 1e45);
        a.frob(-100 * 1e18, -49.5 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 0.5 * 1e18);
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
        assertEq(vow.dai(), 0);
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
        assertEq(vow.dai(), 1 * 1e45);
        a.frob(-100 * 1e18, -49 * 1e18);
        (ink, art) = a.urn();
        assertEq(ink, 0);
        assertEq(art, 1 * 1e18);
        assertEq(a.dai(), 0);
        assertEq(a.gems(), 100 * 1e18);
    }

    function testFail_frob_gate_line_exceeded() public {
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
    function test_flux_other() public {
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
    // Non-msg.sender srcs for flux should be disallowed for now
    function testFail_flux() public {
        (Usr a, Usr b) = init_user();
        b.join(100 * 1e6);
        a.flux(address(b), address(a), 100 * 1e18);
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

        // Can now interact directly with the vat to exit

        a.frobDirect(address(a), address(a), address(a), -100 * 1e18, -50 * 1e18);
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
