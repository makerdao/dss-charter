// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.12;

import "ds-test/test.sol";

import "../DssProxyActionsCharter.sol";
import "../SubCdpManager.sol";
import {CharterManager, CharterManagerImp} from "../CharterManager.sol";
import {FakeMainManager} from "./SubCdpManager.t.sol";

import {ManagedGemJoin} from "lib/dss-gem-joins/src/join-managed.sol";

import {DssDeployTestBase} from "dss-deploy/DssDeploy.t.base.sol";
import {WBTC} from "dss-gem-joins/tokens/WBTC.sol";
import {DSValue} from "ds-value/value.sol";
import {ProxyRegistry, DSProxyFactory, DSProxy} from "proxy-registry/ProxyRegistry.sol";
import {WETH9_} from "ds-weth/weth9.sol";

interface HevmStoreLike {
    function store(address, bytes32, bytes32) external;
}

contract ProxyCalls {
    DSProxy proxy;
    address dssProxyActions;
    address dssProxyActionsEnd;

    function transfer(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function open(bytes32, address) public returns (uint256 cdp) {
        bytes memory response = proxy.execute(dssProxyActions, msg.data);
        assembly {
            cdp := mload(add(response, 0x20))
        }
    }

    function cdpAllow(uint256, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function urnAllow(address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function hope(address, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function nope(address, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function daiJoin_join(address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function flux(uint256, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function move(uint256, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function frob(uint256, int256, int256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function quit(uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function lockETH(address, uint256) public payable {
        (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data));
        require(success, "");
    }

    function safeLockETH(address, uint256, address) public payable {
        (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data));
        require(success, "");
    }

    function lockGem(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function safeLockGem(address, uint256, uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function freeETH(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function freeGem(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function exitETH(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function exitGem(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function draw(address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipe(address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAll(address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function safeWipe(address, uint256, uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function safeWipeAll(address, uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function lockETHAndDraw(address, address, address, uint256, uint256) public payable {
        (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data));
        require(success, "");
    }

    function openLockETHAndDraw(address, address, address, bytes32, uint256) public payable returns (uint256 cdp) {
        address payable target = address(proxy);
        bytes memory data = abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data);
        assembly {
            let succeeded := call(sub(gas(), 5000), target, callvalue(), add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize()
            let response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            cdp := mload(add(response, 0x60))

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    function lockGemAndDraw(address, address, address, uint256, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function openLockGemAndDraw(address, address, address, bytes32, uint256, uint256) public returns (uint256 cdp) {
        bytes memory response = proxy.execute(dssProxyActions, msg.data);
        assembly {
            cdp := mload(add(response, 0x20))
        }
    }

    function wipeAndFreeETH(address, address, uint256, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAllAndFreeETH(address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAndFreeGem(address, address, uint256, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAllAndFreeGem(address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function end_freeETH(address a, address b, uint256 c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("freeETH(address,address,uint256)", a, b, c));
    }

    function end_freeGem(address a, address b, uint256 c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("freeGem(address,address,uint256)", a, b, c));
    }

    function end_pack(address a, address b, uint256 c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("pack(address,address,uint256)", a, b, c));
    }

    function end_cashETH(address a, address b, bytes32 c, uint256 d) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("cashETH(address,address,bytes32,uint256)", a, b, c, d));
    }

    function end_cashGem(address a, address b, bytes32 c, uint256 d) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("cashGem(address,address,bytes32,uint256)", a, b, c, d));
    }
}

contract DssProxyActionsTest is DssDeployTestBase, ProxyCalls {
    CharterManagerImp charter;
    address charterProxy;
    SubCdpManager manager;
    FakeMainManager mainManager;

    ManagedGemJoin ethManagedJoin;
    ManagedGemJoin wbtcJoin;
    WBTC wbtc;
    DSValue pipWBTC;
    ProxyRegistry registry;
    WETH9_ realWeth;

    function cheat_cage() public {
        HevmStoreLike(address(hevm)).store(address(vat), bytes32(uint256(10)), bytes32(uint256(0)));
    }

    function setUp() public override {
        super.setUp();
        deployKeepAuth();

        // Create a real WETH token and replace it with a new adapter in the vat
        realWeth = new WETH9_();
        this.deny(address(vat), address(ethManagedJoin));
        ethManagedJoin = new ManagedGemJoin(address(vat), "ETH", address(realWeth));
        this.rely(address(vat), address(ethManagedJoin));

        // Add a token collateral
        wbtc = new WBTC(1000 * 10 ** 8);
        wbtcJoin = new ManagedGemJoin(address(vat), "WBTC", address(wbtc));

        pipWBTC = new DSValue();
        dssDeploy.deployCollateralFlip("WBTC", address(wbtcJoin), address(pipWBTC));
        pipWBTC.poke(bytes32(uint256(50 ether))); // Price 50 DAI = 1 WBTC (in precision 18)
        this.file(address(spotter), "WBTC", "mat", uint256(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(vat), bytes32("WBTC"), bytes32("line"), uint256(10000 * 10 ** 45));
        spotter.poke("WBTC");
        (,,uint256 spot,,) = vat.ilks("WBTC");
        assertEq(spot, 50 * RAY * RAY / 1500000000 ether);

        // Deploy CharterManager
        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow), address(spotter))));
        charter = CharterManagerImp(address(base));

        mainManager = new FakeMainManager();
        manager = new SubCdpManager(address(vat), address(mainManager), address(charter));

        ethManagedJoin.rely(address(charter));
        ethManagedJoin.deny(address(this));    // Only access should be through charter
        wbtcJoin.rely(address(charter));
        wbtcJoin.deny(address(this));    // Only access should be through charter

        // Deploy proxy factory and create a proxy
        DSProxyFactory factory = new DSProxyFactory();
        registry = new ProxyRegistry(address(factory));
        dssProxyActions = address(new DssProxyActionsCharter(address(vat), address(charter), address(manager)));
        dssProxyActionsEnd = address(new DssProxyActionsEndCharter(address(vat), address(charter), address(manager)));
        proxy = DSProxy(registry.build());
        charterProxy = charter.getOrCreateProxy(address(proxy));
    }

    function ink(bytes32 ilk, address urn) public view returns (uint256 inkV) {
        (inkV,) = vat.urns(ilk, urn);
    }

    function art(bytes32 ilk, address urn) public view returns (uint256 artV) {
        (,artV) = vat.urns(ilk, urn);
    }

    function testTransfer() public {
        wbtc.transfer(address(proxy), 10);
        assertEq(wbtc.balanceOf(address(proxy)), 10);
        assertEq(wbtc.balanceOf(address(123)), 0);
        this.transfer(address(wbtc), address(123), 4);
        assertEq(wbtc.balanceOf(address(proxy)), 6);
        assertEq(wbtc.balanceOf(address(123)), 4);
    }

    function testLockETH() public {
        uint256 initialBalance = address(this).balance;
        uint256 cdp = this.open("ETH", address(proxy));
        assertEq(ink("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        assertEq(ink("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    function testSafeLockETH() public {
        uint256 initialBalance = address(this).balance;
        uint256 cdp = this.open("ETH", address(proxy));
        assertEq(ink("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        this.safeLockETH{value: 2 ether}(address(ethManagedJoin), cdp, address(proxy));
        assertEq(ink("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    function testLockGem() public {
        uint256 cdp = this.open("WBTC", address(proxy));
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        assertEq(ink("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.lockGem(address(wbtcJoin), cdp, 2 * 10 ** 8);
        assertEq(ink("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 2 * 10 ** 8);
    }

    function testSafeLockGem() public {
        uint256 cdp = this.open("WBTC", address(proxy));
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        assertEq(ink("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.safeLockGem(address(wbtcJoin), cdp, 2 * 10 ** 8, address(proxy));
        assertEq(ink("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 2 * 10 ** 8);
    }

    function testFreeETH() public {
        uint256 initialBalance = address(this).balance;
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.freeETH(address(ethManagedJoin), cdp, 1 ether);
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 1 ether);
        assertEq(address(this).balance, initialBalance - 1 ether);
    }

    function testFreeGem() public {
        wbtc.approve(address(proxy), 5 * 10 ** 8);
        uint256 cdp = this.open("WBTC", address(proxy));
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.lockGem(address(wbtcJoin), cdp, 2 * 10 ** 8);
        this.freeGem(address(wbtcJoin), cdp, 1 * 10 ** 8);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 1 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 1 * 10 ** 8);
    }

    function testDraw() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        assertEq(dai.balanceOf(address(this)), 0);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 300 ether);
    }

    function testDrawAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH"); // This is actually not necessary as `draw` will also call drip
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        assertEq(dai.balanceOf(address(this)), 0);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), mul(300 ether, RAY) / (1.05 * 10 ** 27) + 1); // Extra wei due rounding
    }

    function testWipe() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 100 ether);
        this.wipe(address(daiJoin), cdp, 100 ether);
        assertEq(dai.balanceOf(address(this)), 200 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 200 ether);
    }

    function testWipeAll() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipeAll(address(daiJoin), cdp);
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
    }

    function testSafeWipe() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 100 ether);
        this.safeWipe(address(daiJoin), cdp, 100 ether, address(proxy));
        assertEq(dai.balanceOf(address(this)), 200 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 200 ether);
    }

    function testSafeWipeAll() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.safeWipeAll(address(daiJoin), cdp, address(proxy));
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
    }

    function testWipeAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 100 ether);
        this.wipe(address(daiJoin), cdp, 100 ether);
        assertEq(dai.balanceOf(address(this)), 200 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), mul(200 ether, RAY) / (1.05 * 10 ** 27) + 1);
    }

    function testWipeAllAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETH{value: 2 ether}(address(ethManagedJoin), cdp);
        this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipe(address(daiJoin), cdp, 300 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
    }

    function testWipeAllAfterDrip2() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH"); // This is actually not necessary as `draw` will also call drip
        uint256 cdp = this.open("ETH", address(proxy));
        uint256 times = 30;
        this.lockETH{value: 2 ether * times}(address(ethManagedJoin), cdp);
        for (uint256 i = 0; i < times; i++) {
            this.draw(address(jug), address(daiJoin), cdp, 300 ether);
        }
        dai.approve(address(proxy), 300 ether * times);
        this.wipe(address(daiJoin), cdp, 300 ether * times);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
    }

    function testLockETHAndDraw() public {
        uint256 cdp = this.open("ETH", address(proxy));
        uint256 initialBalance = address(this).balance;
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        this.lockETHAndDraw{value: 2 ether}(address(jug), address(ethManagedJoin), address(daiJoin), cdp, 300 ether);
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    function testOpenLockETHAndDraw() public {
        uint256 initialBalance = address(this).balance;
        assertEq(dai.balanceOf(address(this)), 0);
        uint256 cdp = this.openLockETHAndDraw{value: 2 ether}(address(jug), address(ethManagedJoin), address(daiJoin), "ETH", 300 ether);
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    function testLockGemAndDraw() public {
        wbtc.approve(address(proxy), 5 * 10 ** 8);
        uint256 cdp = this.open("WBTC", address(proxy));
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.lockGemAndDraw(address(jug), address(wbtcJoin), address(daiJoin), cdp, 2 * 10 ** 8, 10 ether);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(dai.balanceOf(address(this)), 10 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 2 * 10 ** 8);
    }

    function testOpenLockGemAndDraw() public {
        wbtc.approve(address(proxy), 5 * 10 ** 8);
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        assertEq(dai.balanceOf(address(this)), 0);
        uint256 prevBalance = wbtc.balanceOf(address(this));
        uint256 cdp = this.openLockGemAndDraw(address(jug), address(wbtcJoin), address(daiJoin), "WBTC", 2 * 10 ** 8, 10 ether);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(dai.balanceOf(address(this)), 10 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 2 * 10 ** 8);
    }

    function testWipeAndFreeETH() public {
        uint256 cdp = this.open("ETH", address(proxy));
        uint256 initialBalance = address(this).balance;
        this.lockETHAndDraw{value: 2 ether}(address(jug), address(ethManagedJoin), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 250 ether);
        this.wipeAndFreeETH(address(ethManagedJoin), address(daiJoin), cdp, 1.5 ether, 250 ether);
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0.5 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
        assertEq(address(this).balance, initialBalance - 0.5 ether);
    }

    function testWipeAllAndFreeETH() public {
        uint256 cdp = this.open("ETH", address(proxy));
        uint256 initialBalance = address(this).balance;
        this.lockETHAndDraw{value: 2 ether}(address(jug), address(ethManagedJoin), address(daiJoin), cdp, 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipeAllAndFreeETH(address(ethManagedJoin), address(daiJoin), cdp, 1.5 ether);
        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0.5 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(address(this).balance, initialBalance - 0.5 ether);
    }

    function testWipeAndFreeGem() public {
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        uint256 cdp = this.open("WBTC", address(proxy));
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.lockGemAndDraw(address(jug), address(wbtcJoin), address(daiJoin), cdp, 2 * 10 ** 8, 10 ether);
        dai.approve(address(proxy), 8 ether);
        this.wipeAndFreeGem(address(wbtcJoin), address(daiJoin), cdp, 1.5 * 10 ** 8, 8 ether);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 0.5 ether);
        assertEq(art("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);
        assertEq(dai.balanceOf(address(this)), 2 ether);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 0.5 * 10 ** 8);
    }

    function testWipeAllAndFreeGem() public {
        wbtc.approve(address(proxy), 2 * 10 ** 8);
        uint256 cdp = this.open("WBTC", address(proxy));
        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.lockGemAndDraw(address(jug), address(wbtcJoin), address(daiJoin), cdp, 2 * 10 ** 8, 10 ether);
        dai.approve(address(proxy), 10 ether);
        this.wipeAllAndFreeGem(address(wbtcJoin), address(daiJoin), cdp, 1.5 * 10 ** 8);
        assertEq(ink("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 0.5 ether);
        assertEq(art("WBTC",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(wbtc.balanceOf(address(this)), prevBalance - 0.5 * 10 ** 8);
    }

    function testHopeNope() public {
        assertEq(vat.can(address(proxy), address(123)), 0);
        this.hope(address(vat), address(123));
        assertEq(vat.can(address(proxy), address(123)), 1);
        this.nope(address(vat), address(123));
        assertEq(vat.can(address(proxy), address(123)), 0);
    }

    function testQuit() public {
        uint256 cdp = this.open("ETH", address(proxy));
        this.lockETHAndDraw{value: 1 ether}(address(jug), address(ethManagedJoin), address(daiJoin), cdp, 50 ether);

        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 1 ether);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 50 ether);
        assertEq(ink("ETH", address(proxy)), 0);
        assertEq(art("ETH", address(proxy)), 0);

        cheat_cage();
        this.hope(address(vat), address(charter));
        this.quit(cdp, address(proxy));

        assertEq(ink("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(art("ETH",charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(ink("ETH", address(proxy)), 1 ether);
        assertEq(art("ETH", address(proxy)), 50 ether);
    }

    function testExitEth() public {
        uint256 cdp = this.open("ETH", address(proxy));
        realWeth.deposit{value: 1 ether}();
        realWeth.approve(address(charter), uint256(-1));
        charter.join(address(ethManagedJoin), manager.urns(cdp), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        assertEq(vat.gem("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 1 ether);

        uint256 prevBalance = address(this).balance;
        this.exitETH(address(ethManagedJoin), cdp, 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        assertEq(vat.gem("ETH", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(address(this).balance, prevBalance + 1 ether);
    }

    function testExitGem() public {
        uint256 cdp = this.open("WBTC", address(proxy));
        wbtc.approve(address(charter), 2 * 10 ** 8);
        charter.join(address(wbtcJoin), manager.urns(cdp), 2 * 10 ** 8);
        assertEq(vat.gem("WBTC", address(this)), 0);
        assertEq(vat.gem("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 2 ether);

        uint256 prevBalance = wbtc.balanceOf(address(this));
        this.exitGem(address(wbtcJoin), cdp, 2 * 10 ** 8);
        assertEq(vat.gem("WBTC", address(this)), 0);
        assertEq(vat.gem("WBTC", charter.getOrCreateProxy(manager.urns(cdp))), 0);
        assertEq(wbtc.balanceOf(address(this)), prevBalance + 2 * 10 ** 8);
    }

    // TODO: this still fails
    function testEnd() public {
        uint256 cdpEth = this.open("ETH", address(proxy));
        uint256 cdpWbtc = this.open("WBTC", address(proxy));

        this.lockETHAndDraw{value: 2 ether}(address(jug), address(ethManagedJoin), address(daiJoin), cdpEth, 300 ether);
        wbtc.approve(address(proxy), 1 * 10 ** 8);
        this.lockGemAndDraw(address(jug), address(wbtcJoin), address(daiJoin), cdpWbtc, 1 * 10 ** 8, 5 ether);

        this.cage(address(end));
        end.cage("ETH");
        end.cage("WBTC");

        (uint256 inkV, uint256 artV) = vat.urns("ETH", charter.getOrCreateProxy(manager.urns(cdpEth)));
        assertEq(inkV, 2 ether);
        assertEq(artV, 300 ether);

        (inkV, artV) = vat.urns("WBTC", charter.getOrCreateProxy(manager.urns(cdpWbtc)));
        assertEq(inkV, 1 ether);
        assertEq(artV, 5 ether);

        uint256 prevBalanceETH = address(this).balance;
        this.end_freeETH(address(ethManagedJoin), address(end), cdpEth);
        (inkV, artV) = vat.urns("ETH", charter.getOrCreateProxy(manager.urns(cdpEth)));
        assertEq(inkV, 0);
        assertEq(artV, 0);
        uint256 remainInkVal = 2 ether - 300 * end.tag("ETH") / 10 ** 9; // 2 ETH (deposited) - 300 DAI debt * ETH cage price
        assertEq(address(this).balance, prevBalanceETH + remainInkVal);

        uint256 prevBalanceWBTC = wbtc.balanceOf(address(this));
        this.end_freeGem(address(wbtcJoin), address(end), cdpWbtc);
        (inkV, artV) = vat.urns("WBTC", charter.getOrCreateProxy(manager.urns(cdpWbtc)));
        assertEq(inkV, 0);
        assertEq(artV, 0);
        remainInkVal = (1 ether - 5 * end.tag("WBTC") / 10 ** 9) / 10 ** 10; // 1 WBTC (deposited) - 5 DAI debt * WBTC cage price
        assertEq(wbtc.balanceOf(address(this)), prevBalanceWBTC + remainInkVal);

        end.thaw();

        end.flow("ETH");
        end.flow("WBTC");

        dai.approve(address(proxy), 305 ether);
        this.end_pack(address(daiJoin), address(end), 305 ether);

        this.end_cashETH(address(ethManagedJoin), address(end), "ETH", 305 ether);
        this.end_cashGem(address(wbtcJoin), address(end), "WBTC", 305 ether);

        assertEq(address(this).balance, prevBalanceETH + 2 ether - 1); // (-1 rounding)
        assertEq(wbtc.balanceOf(address(this)), prevBalanceWBTC + 1 * 10 ** 8 - 1); // (-1 rounding)
    }

    receive() external payable {}
}