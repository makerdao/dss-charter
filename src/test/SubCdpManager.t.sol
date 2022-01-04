pragma solidity >=0.5.12;

import "./TestBase.sol";
import { DssDeployTestBase, Vat } from "dss-deploy/DssDeploy.t.base.sol";
import { SubCdpManager } from "src/SubCdpManager.sol";
import { ManagedGemJoin } from "dss-gem-joins/join-managed.sol";
import { CharterManager, CharterManagerImp } from "src/CharterManager.sol";

interface HevmLike {
    function warp(uint256) external;
    function roll(uint256) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external returns (bytes32);
}

contract FakeUser {

    function doCdpAllow(
        SubCdpManager manager,
        uint256 cdp,
        address usr,
        uint256 ok
    ) public {
        manager.cdpAllow(cdp, usr, ok);
    }

    function doUrnAllow(
        SubCdpManager manager,
        address usr,
        uint256 ok
    ) public {
        manager.urnAllow(usr, ok);
    }

    function doFrob(
        SubCdpManager manager,
        uint256 cdp,
        int256 dink,
        int256 dart
    ) public {
        manager.frob(cdp, dink, dart);
    }

    function doHope(
        Vat vat,
        address usr
    ) public {
        vat.hope(usr);
    }

    function doVatFrob(
        Vat vat,
        bytes32 i,
        address u,
        address v,
        address w,
        int256 dink,
        int256 dart
    ) public {
        vat.frob(i, u, v, w, dink, dart);
    }
}

contract FakeMainManager {
    uint256 public cdpi;

    function open(bytes32 ilk, address usr) public returns (uint256) {
        cdpi = cdpi + 1;
        return cdpi;
    }
}

contract SubCdpManagerTest is DssDeployTestBase {
    SubCdpManager manager;
    FakeUser user;
    FakeMainManager mainManager;
    ManagedGemJoin adapter;
    CharterManagerImp charter;

    function setUpCharter() public {
        // although there is already a regular ETH gemJoin it is fine
        adapter = new ManagedGemJoin(address(vat), "ETH", address(weth));

        // get auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(1)));
        vat.rely(address(adapter));
        // give up auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(0)));

        CharterManager base = new CharterManager();
        base.setImplementation(address(new CharterManagerImp(address(vat), address(vow), address(spotter))));
        charter = CharterManagerImp(address(base));
        CharterManager(address(charter)).deny(address(this));

        adapter.rely(address(charter));
        adapter.deny(address(this));    // Only access should be through charter
    }

    function charterEthUrn(uint256 cdp_) public {
        HevmLike(address(hevm)).store(address(charter), keccak256(abi.encode(address(this), 1)), bytes32(uint256(1)));
        charter.file("ETH", "gate", 1);
        charter.file("ETH", manager.urns(cdp_), "nib", 0);
        charter.file("ETH", manager.urns(cdp_), "peace", 0);
        charter.file("ETH", manager.urns(cdp_), "uline", 50 * 1e45);
        HevmLike(address(hevm)).store(address(charter), keccak256(abi.encode(address(this), 1)), bytes32(uint256(0)));
    }

    function setUpManager() public {
        deploy();
        user = new FakeUser();

        setUpCharter();
        mainManager = new FakeMainManager();
        manager = new SubCdpManager(address(vat), address(mainManager), address(charter));
    }

    function testOpenCDP() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        assertEq(cdp, 1);
        assertEq(charter.can(address(bytes20(manager.urns(cdp))), address(manager)), 1);
        assertEq(manager.owns(cdp), address(this));
    }

    function testOpenCDPOtherAddress() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(123));
        assertEq(manager.owns(cdp), address(123));
    }

    function testFailOpenCDPZeroAddress() public {
        setUpManager();
        manager.open("ETH", address(0));
    }

    function testAllowAllowed() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        manager.cdpAllow(cdp, address(user), 1);
        user.doCdpAllow(manager, cdp, address(123), 1);
        assertEq(manager.cdpCan(address(this), cdp, address(123)), 1);
    }

    function testFailAllowNotAllowed() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        user.doCdpAllow(manager, cdp, address(123), 1);
    }

    function testFrob() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.urns(cdp)), 50 ether * RAY);
        assertEq(vat.dai(address(this)), 0);
        manager.move(cdp, address(this), 50 ether * RAY);
        assertEq(vat.dai(manager.urns(cdp)), 0);
        assertEq(vat.dai(address(this)), 50 ether * RAY);
        assertEq(dai.balanceOf(address(this)), 0);
        vat.hope(address(daiJoin));
        daiJoin.exit(address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
    }

    function testFrobAllowed() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.cdpAllow(cdp, address(user), 1);
        user.doFrob(manager, cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.urns(cdp)), 50 ether * RAY);
    }

    function testFailFrobNotAllowed() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        user.doFrob(manager, cdp, 1 ether, 50 ether);
    }

    function testFrobGetCollateralBack() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);
        manager.frob(cdp, -int256(1 ether), -int256(50 ether));
        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.gem("ETH", charter.proxy(manager.urns(cdp))), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        manager.flux(cdp, address(this), 1 ether);
        assertEq(vat.gem("ETH", charter.proxy(manager.urns(cdp))), 0);
        assertEq(vat.gem("ETH", charter.proxy(address(this))), 1 ether);
        uint256 prevBalance = weth.balanceOf(address(this));
        charter.exit(address(adapter), address(this), 1 ether);
        assertEq(weth.balanceOf(address(this)), prevBalance + 1 ether);
    }

    function testQuit() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);
        (uint256 ink, uint256 art) = vat.urns("ETH", charter.proxy(manager.urns(cdp)));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        // get auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(1)));
        vat.cage();
        // give up auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(0)));

        vat.hope(address(charter)); // dst has to approve charter for the fork
        manager.quit(cdp, address(this));
        (ink, art) = vat.urns("ETH", charter.proxy(manager.urns(cdp)));
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
    }

    function testQuitOtherDst() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);

        (uint256 ink, uint256 art) = vat.urns("ETH", charter.proxy(manager.urns(cdp)));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        // get auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(1)));
        vat.cage();
        // give up auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(0)));

        user.doHope(vat, address(charter)); // dst has to approve charter for the fork
        user.doUrnAllow(manager, address(this), 1);
        manager.quit(cdp, address(user));
        (ink, art) = vat.urns("ETH", charter.proxy(manager.urns(cdp)));
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns("ETH", address(user));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
    }

    function testFailQuitOtherDst() public {
        setUpManager();
        uint256 cdp = manager.open("ETH", address(this));
        charterEthUrn(cdp);
        weth.mint(1 ether);
        weth.approve(address(charter), 1 ether);
        charter.join(address(adapter), manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);

        (uint256 ink, uint256 art) = vat.urns("ETH", charter.proxy(manager.urns(cdp)));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        // get auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(1)));
        vat.cage();
        // give up auth in vat
        HevmLike(address(hevm)).store(address(vat), keccak256(abi.encode(address(this), 0)), bytes32(uint256(0)));

        user.doHope(vat, address(charter)); // dst has to approve charter for the fork
        manager.quit(cdp, address(user));
    }
}

