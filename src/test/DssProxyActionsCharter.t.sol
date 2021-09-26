pragma solidity ^0.6.12;

import "ds-test/test.sol";

import "../DssProxyActionsCharter.sol";
import {CharterManager, CharterManagerImp} from "../CharterManager.sol";
import {ManagedGemJoin} from "lib/dss-gem-joins/src/join-managed.sol";

import {DssDeployTestBase, GemJoin, Flipper} from "dss-deploy/DssDeploy.t.base.sol";
import {WBTC} from "dss-gem-joins/tokens/WBTC.sol"; //
//import {DGD} from "dss-gem-joins/tokens/DGD.sol";
//import {GemJoin3} from "dss-gem-joins/join-3.sol";
//import {GemJoin4} from "dss-gem-joins/join-4.sol";
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
/* TODO: remove these
    function open(address, bytes32, address) public returns (uint256 cdp) {
        bytes memory response = proxy.execute(dssProxyActions, msg.data);
        assembly {
            cdp := mload(add(response, 0x20))
        }
    }

    function give(address, uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function giveToProxy(address, address, uint256, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function cdpAllow(address, uint256, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function urnAllow(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }
*/
    function hope(address, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function nope(address, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    // TODO: change signatures of all of these as we added stuff
    function flux(address, bytes32, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function move(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function frob(address, bytes32, int256, int256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function quit(address, bytes32, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function lockETH(address, address) public payable {
        (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data));
        require(success, "");
    }

    function lockGem(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function freeETH(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function freeGem(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function exitETH(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function exitGem(address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function draw(address, bytes32, address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipe(address, bytes32, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAll(address, bytes32, address) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function lockETHAndDraw(address, address, address, address, uint256) public payable {
        (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxyActions, msg.data));
        require(success, "");
    }

    function lockGemAndDraw(address, address, address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAndFreeETH(address, address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAllAndFreeETH(address, address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAndFreeGem(address, address, address, uint256, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function wipeAllAndFreeGem(address, address, address, uint256) public {
        proxy.execute(dssProxyActions, msg.data);
    }

    function end_freeETH(address a, address b, address c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("freeETH(address,address,address)", a, b, c));
    }

    function end_freeGem(address a, address b, address c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("freeGem(address,address,address)", a, b, c));
    }

    function end_pack(address a, address b, uint256 c) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("pack(address,address,uint256)", a, b, c));
    }

    function end_cashETH(address a, address b, address c, bytes32 d, uint256 e) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("cashETH(address,address,address,bytes32,uint256)", a, b, c, d, e));
    }

    function end_cashGem(address a, address b, address c, bytes32 d, uint256 e) public {
        proxy.execute(dssProxyActionsEnd, abi.encodeWithSignature("cashGem(address,address,address,bytes32,uint256)", a, b, c, d, e));
    }
}

contract DssProxyActionsTest is DssDeployTestBase, ProxyCalls {
    CharterManagerImp manager;

    ManagedGemJoin ethManagedJoin;
    ManagedGemJoin dgdJoin;
    WBTC dgd; // TODO: rename dgd to wbtc
    DSValue pipDGD;
    Flipper dgdFlip;
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
        dgd = new WBTC(1000 * 10 ** 8);
        dgdJoin = new ManagedGemJoin(address(vat), "DGD", address(dgd));

        pipDGD = new DSValue();
        dssDeploy.deployCollateralFlip("DGD", address(dgdJoin), address(pipDGD));
        (dgdFlip,,) = dssDeploy.ilks("DGD");
        pipDGD.poke(bytes32(uint256(50 ether))); // Price 50 DAI = 1 DGD (in precision 18)
        this.file(address(spotter), "DGD", "mat", uint256(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(vat), bytes32("DGD"), bytes32("line"), uint256(10000 * 10 ** 45));
        spotter.poke("DGD");
        (,,uint256 spot,,) = vat.ilks("DGD");
        assertEq(spot, 50 * RAY * RAY / 1500000000 ether);

        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow), address(spotter))));
        manager = CharterManagerImp(address(base));

        ethManagedJoin.rely(address(manager));
        ethManagedJoin.deny(address(this));    // Only access should be through manager

        dgdJoin.rely(address(manager));
        dgdJoin.deny(address(this));    // Only access should be through manager

        DSProxyFactory factory = new DSProxyFactory();
        registry = new ProxyRegistry(address(factory));
        dssProxyActions = address(new DssProxyActionsCharter());
        dssProxyActionsEnd = address(new DssProxyActionsEndCharter());
        proxy = DSProxy(registry.build());
    }

    function ink(bytes32 ilk, address urn) public view returns (uint256 inkV) {
        (inkV,) = vat.urns(ilk, urn);
    }

    function art(bytes32 ilk, address urn) public view returns (uint256 artV) {
        (,artV) = vat.urns(ilk, urn);
    }

    function testTransfer() public {
        col.mint(10);
        col.transfer(address(proxy), 10);
        assertEq(col.balanceOf(address(proxy)), 10);
        assertEq(col.balanceOf(address(123)), 0);
        this.transfer(address(col), address(123), 4);
        assertEq(col.balanceOf(address(proxy)), 6);
        assertEq(col.balanceOf(address(123)), 4);
    }
/*
    function testCreateCDP() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        assertEq(cdp, 1);
        assertEq(manager.owns(cdp), address(proxy));
    }

    function testGiveCDP() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        this.give(address(manager), cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
    }

    function testGiveCDPToProxy() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        address userProxy = registry.build(address(123));
        this.giveToProxy(address(registry), address(manager), cdp, address(123));
        assertEq(manager.owns(cdp), userProxy);
    }

    function testGiveCDPToNewProxy() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        assertEq(address(registry.proxies(address(123))), address(0));
        this.giveToProxy(address(registry), address(manager), cdp, address(123));
        DSProxy userProxy = registry.proxies(address(123));
        assertTrue(address(userProxy) != address(0));
        assertEq(userProxy.owner(), address(123));
        assertEq(manager.owns(cdp), address(userProxy));
    }

    function testFailGiveCDPToNewContractProxy() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        FakeUser user = new FakeUser();
        assertEq(address(registry.proxies(address(user))), address(0));
        this.giveToProxy(address(registry), address(manager), cdp, address(user)); // Fails as user is a contract and not a regular address
    }

    function testGiveCDPAllowedUser() public {
        uint256 cdp = this.open(address(manager), "ETH", address(proxy));
        FakeUser user = new FakeUser();
        this.cdpAllow(address(manager), cdp, address(user), 1);
        user.doGive(manager, cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
    }

    function testAllowUrn() public {
        assertEq(manager.urnCan(address(proxy), address(123)), 0);
        this.urnAllow(address(manager), address(123), 1);
        assertEq(manager.urnCan(address(proxy), address(123)), 1);
        this.urnAllow(address(manager), address(123), 0);
        assertEq(manager.urnCan(address(proxy), address(123)), 0);
    }
*/
    function testFlux() public {
        address pp = manager.getOrCreateProxy(address(proxy));
        address tp = manager.getOrCreateProxy(address(this));

        assertEq(dai.balanceOf(address(this)), 0);
        realWeth.deposit{value: 1 ether}();
        realWeth.approve(address(manager), uint256(-1));
        manager.join(address(ethManagedJoin), address(proxy), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        assertEq(vat.gem("ETH", pp), 1 ether);

        this.flux(address(manager), "ETH", address(this), 0.75 ether);

        assertEq(vat.gem("ETH", tp), 0.75 ether);
        assertEq(vat.gem("ETH", pp), 0.25 ether);
    }

    function testFrob() public {
        address pp = manager.getOrCreateProxy(address(proxy));

        assertEq(dai.balanceOf(address(this)), 0);
        realWeth.deposit{value: 1 ether}();
        realWeth.approve(address(manager), uint256(-1));
        manager.join(address(ethManagedJoin), address(proxy), 1 ether);

        this.frob(address(manager), "ETH", 0.5 ether, 60 ether);
        assertEq(vat.gem("ETH", pp), 0.5 ether);
        assertEq(vat.dai(address(proxy)), mul(RAY, 60 ether));
        assertEq(vat.dai(address(this)), 0);

        this.move(address(manager), address(this), mul(RAY, 60 ether));
        assertEq(vat.dai(address(proxy)), 0);
        assertEq(vat.dai(address(this)), mul(RAY, 60 ether));

        vat.hope(address(daiJoin));
        daiJoin.exit(address(this), 60 ether);
        assertEq(dai.balanceOf(address(this)), 60 ether);
    }

    function testLockETH() public {
        uint256 initialBalance = address(this).balance;
        address pt = manager.getOrCreateProxy(address(proxy));

        assertEq(ink("ETH", pt), 0);
        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        assertEq(ink("ETH", pt), 2 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    // How can this be passing???
    function testLockGem() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(proxy), 2 * 10 ** 8);
        assertEq(ink("DGD", pt), 0);
        uint256 prevBalance = dgd.balanceOf(address(this));
        this.lockGem(address(manager), address(dgdJoin), 2 * 10 ** 8);
        assertEq(ink("DGD", pt), 2 ether);
        assertEq(dgd.balanceOf(address(this)), prevBalance - 2 * 10 ** 8);
    }

    function testFreeETH() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        uint256 initialBalance = address(this).balance;
        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        this.freeETH(address(manager), address(ethManagedJoin), 1 ether);
        assertEq(ink("ETH", pt), 1 ether);
        assertEq(address(this).balance, initialBalance - 1 ether);
    }

    function testFreeGem() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(proxy), 2 * 10 ** 8);
        assertEq(ink("DGD", pt), 0);
        uint256 prevBalance = dgd.balanceOf(address(this));
        this.lockGem(address(manager), address(dgdJoin), 2 * 10 ** 8);
        this.freeGem(address(manager), address(dgdJoin), 1 * 10 ** 8);
        assertEq(ink("DGD", pt),  1 ether);
        assertEq(dgd.balanceOf(address(this)), prevBalance - 1 * 10 ** 8);
    }

    function testDraw() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        assertEq(dai.balanceOf(address(this)), 0);
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(art("ETH", pt), 300 ether);
    }

    function testDrawAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");

        address pt = manager.getOrCreateProxy(address(proxy));
        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        assertEq(dai.balanceOf(address(this)), 0);
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(art("ETH", pt), mul(300 ether, RAY) / (1.05 * 10 ** 27) + 1); // Extra wei due rounding
    }

    function testWipe() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 100 ether);
        this.wipe(address(manager), "ETH", address(daiJoin), 100 ether);
        assertEq(dai.balanceOf(address(this)), 200 ether);
        assertEq(art("ETH", pt), 200 ether);
    }

    function testWipeAll() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipeAll(address(manager), "ETH", address(daiJoin));
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(art("ETH", pt), 0);
    }

    function testWipeAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");

        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 100 ether);
        this.wipe(address(manager), "ETH", address(daiJoin), 100 ether);
        assertEq(dai.balanceOf(address(this)), 200 ether);
        assertEq(art("ETH", pt), mul(200 ether, RAY) / (1.05 * 10 ** 27) + 1);
    }

    // TODO: this fails because of left dust!
    function testWipeAllAfterDrip() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");

        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETH{value: 2 ether}(address(manager), address(ethManagedJoin));
        this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipe(address(manager), "ETH", address(daiJoin), 300 ether);
        assertEq(art("ETH", pt), 0);
    }

    // TODO: this fails because of left dust!
    function testWipeAllAfterDrip2() public {
        this.file(address(jug), bytes32("ETH"), bytes32("duty"), uint256(1.05 * 10 ** 27));
        hevm.warp(now + 1);
        jug.drip("ETH");

        address pt = manager.getOrCreateProxy(address(proxy));

        uint256 times = 30;
        this.lockETH{value: 2 ether * times}(address(manager), address(ethManagedJoin));
        for (uint256 i = 0; i < times; i++) {
            this.draw(address(manager), "ETH", address(jug), address(daiJoin), 300 ether);
        }
        dai.approve(address(proxy), 300 ether * times);
        this.wipe(address(manager), "ETH", address(daiJoin), 300 ether * times);
        assertEq(art("ETH", pt), 0);
    }

    function testLockETHAndDraw() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        uint256 initialBalance = address(this).balance;
        assertEq(ink("ETH", pt), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        this.lockETHAndDraw{value: 2 ether}(address(manager), address(jug), address(ethManagedJoin), address(daiJoin), 300 ether);
        assertEq(ink("ETH", pt), 2 ether);
        assertEq(dai.balanceOf(address(this)), 300 ether);
        assertEq(address(this).balance, initialBalance - 2 ether);
    }

    function testLockGemAndDraw() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(proxy), 3 * 10 ** 8);
        assertEq(ink("DGD", pt), 0);
        uint256 prevBalance = dgd.balanceOf(address(this));
        this.lockGemAndDraw(address(manager), address(jug), address(dgdJoin), address(daiJoin), 3 * 10 ** 8, 50 ether);
        assertEq(ink("DGD", pt), 3 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
        assertEq(dgd.balanceOf(address(this)), prevBalance - 3 * 10 ** 8);
    }

    function testWipeAndFreeETH() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        uint256 initialBalance = address(this).balance;
        this.lockETHAndDraw{value: 2 ether}(address(manager), address(jug), address(ethManagedJoin), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 250 ether);
        this.wipeAndFreeETH(address(manager), address(ethManagedJoin), address(daiJoin), 1.5 ether, 250 ether);
        assertEq(ink("ETH", pt), 0.5 ether);
        assertEq(art("ETH", pt), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
        assertEq(address(this).balance, initialBalance - 0.5 ether);
    }

    function testWipeAllAndFreeETH() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        uint256 initialBalance = address(this).balance;
        this.lockETHAndDraw{value: 2 ether}(address(manager), address(jug), address(ethManagedJoin), address(daiJoin), 300 ether);
        dai.approve(address(proxy), 300 ether);
        this.wipeAllAndFreeETH(address(manager), address(ethManagedJoin), address(daiJoin), 1.5 ether);
        assertEq(ink("ETH", pt), 0.5 ether);
        assertEq(art("ETH", pt), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(address(this).balance, initialBalance - 0.5 ether);
    }

    function testWipeAndFreeGem() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(proxy), 2 * 10 ** 8);
        uint256 prevBalance = dgd.balanceOf(address(this));
        this.lockGemAndDraw(address(manager), address(jug), address(dgdJoin), address(daiJoin), 2 * 10 ** 8, 10 ether);
        dai.approve(address(proxy), 8 ether);
        this.wipeAndFreeGem(address(manager), address(dgdJoin), address(daiJoin), 1.5 * 10 ** 8, 8 ether);
        assertEq(ink("DGD", pt), 0.5 ether);
        assertEq(art("DGD", pt), 2 ether);
        assertEq(dai.balanceOf(address(this)), 2 ether);
        assertEq(dgd.balanceOf(address(this)), prevBalance - 0.5 * 10 ** 8);
    }

    function testWipeAllAndFreeGem() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(proxy), 2 * 10 ** 8);
        uint256 prevBalance = dgd.balanceOf(address(this));
        this.lockGemAndDraw(address(manager), address(jug), address(dgdJoin), address(daiJoin), 2 * 10 ** 8, 10 ether);
        dai.approve(address(proxy), 10 ether);
        this.wipeAllAndFreeGem(address(manager), address(dgdJoin), address(daiJoin), 1.5 * 10 ** 8);
        assertEq(ink("DGD", pt), 0.5 ether);
        assertEq(art("DGD", pt), 0);
        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(dgd.balanceOf(address(this)), prevBalance - 0.5 * 10 ** 8);
    }

    function testHopeNope() public {
        assertEq(vat.can(address(proxy), address(123)), 0);
        this.hope(address(vat), address(123));
        assertEq(vat.can(address(proxy), address(123)), 1);
        this.nope(address(vat), address(123));
        assertEq(vat.can(address(proxy), address(123)), 0);
    }

    function testQuit() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETHAndDraw{value: 1 ether}(address(manager), address(jug), address(ethManagedJoin), address(daiJoin), 50 ether);

        assertEq(ink("ETH", pt), 1 ether);
        assertEq(art("ETH", pt), 50 ether);
        assertEq(ink("ETH", address(proxy)), 0);
        assertEq(art("ETH", address(proxy)), 0);

        cheat_cage();
        this.hope(address(vat), address(manager));
        this.quit(address(manager), "ETH", address(proxy));

        assertEq(ink("ETH", pt), 0);
        assertEq(art("ETH", pt), 0);
        assertEq(ink("ETH", address(proxy)), 1 ether);
        assertEq(art("ETH", address(proxy)), 50 ether);
    }

    function testExitEth() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        realWeth.deposit{value: 1 ether}();
        realWeth.approve(address(manager), uint256(-1));
        manager.join(address(ethManagedJoin), address(proxy), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        assertEq(vat.gem("ETH", pt), 1 ether);

        uint256 prevBalance = address(this).balance;
        this.exitETH(address(manager), address(ethManagedJoin), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        assertEq(vat.gem("ETH", pt), 0);
        assertEq(address(this).balance, prevBalance + 1 ether);
    }

    function testExitGem() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        dgd.approve(address(manager), 2 * 10 ** 8);
        manager.join(address(dgdJoin), address(proxy), 2 * 10 ** 8);
        assertEq(vat.gem("DGD", address(this)), 0);
        assertEq(vat.gem("DGD", pt), 2 ether);

        uint256 prevBalance = dgd.balanceOf(address(this));
        this.exitGem(address(manager), address(dgdJoin), 2 * 10 ** 8);
        assertEq(vat.gem("DGD", address(this)), 0);
        assertEq(vat.gem("DGD", pt), 0);
        assertEq(dgd.balanceOf(address(this)), prevBalance + 2 * 10 ** 8);
    }

    function testEnd() public {
        address pt = manager.getOrCreateProxy(address(proxy));

        this.lockETHAndDraw{value: 2 ether}(address(manager), address(jug), address(ethManagedJoin), address(daiJoin), 300 ether);
        dgd.approve(address(proxy), 1 * 10 ** 8);
        this.lockGemAndDraw(address(manager), address(jug), address(dgdJoin), address(daiJoin), 1 * 10 ** 8, 5 ether);

        this.cage(address(end));
        end.cage("ETH");
        end.cage("DGD");

        (uint256 inkV, uint256 artV) = vat.urns("ETH", pt);
        assertEq(inkV, 2 ether);
        assertEq(artV, 300 ether);

        (inkV, artV) = vat.urns("DGD", pt);
        assertEq(inkV, 1 ether);
        assertEq(artV, 5 ether);

        uint256 prevBalanceETH = address(this).balance;
        this.end_freeETH(address(manager), address(ethManagedJoin), address(end));
        (inkV, artV) = vat.urns("ETH", pt);
        assertEq(inkV, 0);
        assertEq(artV, 0);
        uint256 remainInkVal = 2 ether - 300 * end.tag("ETH") / 10 ** 8; // 2 ETH (deposited) - 300 DAI debt * ETH cage price
        assertEq(address(this).balance, prevBalanceETH + remainInkVal);

        uint256 prevBalanceDGD = dgd.balanceOf(address(this));
        this.end_freeGem(address(manager), address(dgdJoin), address(end));
        (inkV, artV) = vat.urns("DGD", pt);
        assertEq(inkV, 0);
        assertEq(artV, 0);
        remainInkVal = (1 ether - 5 * end.tag("DGD") / 10 ** 8) / 10 ** 8; // 1 DGD (deposited) - 5 DAI debt * DGD cage price
        assertEq(dgd.balanceOf(address(this)), prevBalanceDGD + remainInkVal);

        end.thaw();

        end.flow("ETH");
        end.flow("DGD");

        dai.approve(address(proxy), 310 ether);
        this.end_pack(address(daiJoin), address(end), 310 ether);

        this.end_cashETH(address(manager), address(ethManagedJoin), address(end), "ETH", 310 ether);
        this.end_cashGem(address(manager), address(dgdJoin), address(end), "DGD", 310 ether);

        assertEq(address(this).balance, prevBalanceETH + 2 ether - 1); // (-1 rounding)
        assertEq(dgd.balanceOf(address(this)), prevBalanceDGD + 1 * 10 ** 8 - 1); // (-1 rounding)
    }

    receive() external payable {}
}