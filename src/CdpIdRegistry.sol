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

pragma solidity >=0.6.12;

interface CdpManagerLike {
    function open(bytes32, address) external returns (uint256);
}

contract CdpIdRegistry {
    mapping (uint256 => address) public owns; // CDPId => Owner
    mapping (uint256 => bytes32) public ilks; // CDPId => Ilk
    mapping (bytes32 => mapping (address => uint256)) public cdps; // Owner => Ilk => CDPId

    // for fast ownership check
    mapping (uint256 => mapping(bytes32 => address)) public ownsIlk; // CDPId => Ilk => Owner

    address public immutable cdpManager;

    event NewCdpId(address indexed sender, address indexed owner, uint256 indexed cdp);

    constructor(address cdpManager_) public {
        cdpManager = cdpManager_;
    }

    function open(
        bytes32 ilk,
        address usr
    ) public returns (uint256) {
        require(usr != address(0), "usr-address-0");
        require(cdps[ilk][usr] == 0, "usr-cdp-exists");

        uint256 cdpi = CdpManagerLike(cdpManager).open(ilk, address(this));
        owns[cdpi] = usr;
        ilks[cdpi] = ilk;
        cdps[ilk][usr] = cdpi;

        ownsIlk[cdpi][ilk] = usr;

        emit NewCdpId(msg.sender, usr, cdpi);
        return cdpi;
    }
}