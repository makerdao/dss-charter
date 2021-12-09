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

interface Hopelike {
    function hope(address) external;
}

interface MainCdpManagerLike {
    function open(bytes32, address) external returns (uint256);
}

contract UrnHandler {
    address immutable public usr;

    constructor(address vat_, address usr_) public {
        usr = usr_;
        Hopelike(vat_).hope(msg.sender);
    }
}

contract SubCdpManager {

    address immutable           public vat;
    address immutable           public mainManager;

    mapping (uint256 => address) public urns; // CDPId => UrnHandler
    mapping (address => address) public urnsByOwners; // Owner => UrnHandler
    mapping (uint256 => address) public owns; // CDPId => Owner
    mapping (uint256 => bytes32) public ilks; // CDPId => Ilk


    mapping (
        address => mapping (
            uint256 => mapping (
                address => uint256
            )
        )
    ) public cdpCan;                          // Owner => CDPId => Allowed Addr => True/False

    event NewCdp(address indexed usr, address indexed own, uint256 indexed cdp);

    modifier cdpOwned(
        uint256 cdp
    ) {
        require(msg.sender == owns[cdp], "SubCdpManager/cdp-not-owned");
        _;
    }

    modifier cdpAllowed(
        uint256 cdp
    ) {
        require(msg.sender == owns[cdp] || cdpCan[owns[cdp]][cdp][msg.sender] == 1, "SubCdpManager/cdp-not-allowed");
        _;
    }

    constructor(address vat_, address mainManager_) public {
        vat = vat_;
        mainManager = mainManager_;
    }

    // Allow/disallow a usr address to manage the cdp.
    function cdpAllow(
        uint256 cdp,
        address usr,
        uint256 ok
    ) public cdpAllowed(cdp) {
        cdpCan[owns[cdp]][cdp][usr] = ok;
    }

    // Open a new cdp for a given usr address.
    function open(
        bytes32 ilk,
        address usr
    ) public returns (uint256) {
        require(usr != address(0), "SubCdpManager/usr-address-0");
        require(urnsByOwners[usr] == address(0), "SubCdpManager/usr-cdp-exists");

        uint256 cdpi = MainCdpManagerLike(mainManager).open(ilk, usr);
        address urn = address(new UrnHandler(vat, usr));
        urns[cdpi] = urn;
        urnsByOwners[usr] = urn;
        owns[cdpi] = usr;
        ilks[cdpi] = ilk;

        emit NewCdp(msg.sender, usr, cdpi);
        return cdpi;
    }
}
