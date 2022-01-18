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

import "../CdpRegistry.sol";
import "./TestBase.sol";

contract Usr {}

contract MockCdpManager {
    uint256 public cdpi;
    mapping (uint256 => address) public owns; // CDPId => Owner
    mapping (uint256 => bytes32) public ilks; // CDPId => Ilk

    function open(bytes32 ilk, address usr) public returns (uint256) {
        cdpi = cdpi + 1;
        owns[cdpi] = usr;
        ilks[cdpi] = ilk;
        return cdpi;
    }
}

contract CdpRegistryTest is TestBase {

    MockCdpManager cdpManager;
    CdpRegistry    cdpRegistry;
    address        usr1;
    address        usr2;

    function setUp() public virtual {
        cdpManager  = new MockCdpManager();
        cdpRegistry = new CdpRegistry(address(cdpManager));
        usr1        = address(new Usr());
        usr2        = address(new Usr());
    }

    function test_open_different_ilks() public {
        uint256 cdp = cdpRegistry.open("ILK1", usr1);
        assertEq(cdp, 1);
        assertEq(cdpRegistry.ilks(1), "ILK1");
        assertEq(cdpRegistry.owns(1), usr1);
        assertEq(cdpRegistry.cdps("ILK1", usr1), 1);
        assertEq(cdpManager.ilks(1), "ILK1");
        assertEq(cdpManager.owns(1), address(cdpRegistry));

        cdp = cdpRegistry.open("ILK2", usr1);
        assertEq(cdp, 2);
        assertEq(cdpRegistry.ilks(2), "ILK2");
        assertEq(cdpRegistry.owns(2), usr1);
        assertEq(cdpRegistry.cdps("ILK2", usr1), 2);
        assertEq(cdpManager.ilks(2), "ILK2");
        assertEq(cdpManager.owns(2), address(cdpRegistry));
    }

    function test_open_different_users() public {
        uint256 cdp = cdpRegistry.open("ILK1", usr1);
        assertEq(cdp, 1);
        assertEq(cdpRegistry.ilks(1), "ILK1");
        assertEq(cdpRegistry.owns(1), usr1);
        assertEq(cdpRegistry.cdps("ILK1", usr1), 1);
        assertEq(cdpManager.ilks(1), "ILK1");
        assertEq(cdpManager.owns(1), address(cdpRegistry));

        cdp = cdpRegistry.open("ILK1", usr2);
        assertEq(cdp, 2);
        assertEq(cdpRegistry.ilks(2), "ILK1");
        assertEq(cdpRegistry.owns(2), usr2);
        assertEq(cdpRegistry.cdps("ILK1", usr2), 2);
        assertEq(cdpManager.ilks(2), "ILK1");
        assertEq(cdpManager.owns(2), address(cdpRegistry));
    }

    function testFail_open_same_ilk_same_user() public {
        uint256 cdp = cdpRegistry.open("ILK1", usr1);
        cdp = cdpRegistry.open("ILK1", usr1);
    }
}
