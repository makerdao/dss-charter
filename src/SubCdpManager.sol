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

interface JoinManagerLike {
    function open(bytes32, address) external returns (uint256);
    function exit(address, address, address, uint256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function flux(bytes32, address, address, uint256) external;
    function quit(bytes32, address, address) external;
}

contract UrnHandler {
    address immutable public usr;

    constructor(address joinManager_, address usr_) public {
        usr = usr_;
        Hopelike(joinManager_).hope(msg.sender);
    }
}

contract SubCdpManager {

    address immutable           public vat;
    address immutable           public mainManager;
    address immutable           public joinManager;

    mapping (uint256 => address) public urns; // CDPId => UrnHandler
    mapping (uint256 => address) public owns; // CDPId => Owner
    mapping (uint256 => bytes32) public ilks; // CDPId => Ilk

    mapping (
        address => mapping (
            uint256 => mapping (
            address => uint256
            )
        )
    ) public cdpCan;                          // Owner => CDPId => Allowed Addr => True/False

    mapping (
            address => mapping (
            address => uint
        )
    ) public urnCan;                          // Urn => Allowed Addr => True/False

    event NewCdp(address indexed usr, address indexed own, uint256 indexed cdp);

    modifier cdpAllowed(
        uint256 cdp
    ) {
        require(msg.sender == owns[cdp] || cdpCan[owns[cdp]][cdp][msg.sender] == 1, "SubCdpManager/cdp-not-allowed");
        _;
    }

    modifier urnAllowed(
        address urn
    ) {
        require(msg.sender == urn || urnCan[urn][msg.sender] == 1, "urn-not-allowed");
        _;
    }

    constructor(address vat_, address mainManager_, address joinManager_) public {
        vat = vat_;
        mainManager = mainManager_;
        joinManager = joinManager_;
    }

    // Allow/disallow a usr address to manage the cdp.
    function cdpAllow(
        uint256 cdp,
        address usr,
        uint256 ok
    ) public cdpAllowed(cdp) {
        cdpCan[owns[cdp]][cdp][usr] = ok;
    }

    // Allow/disallow a usr address to quit to the the sender urn.
    function urnAllow(
        address usr,
        uint ok
    ) public {
        urnCan[msg.sender][usr] = ok;
    }

    // Open a new cdp for a given usr address.
    function open(
        bytes32 ilk,
        address usr
    ) public returns (uint256) {
        require(usr != address(0), "SubCdpManager/usr-address-0");

        uint256 cdpi = MainCdpManagerLike(mainManager).open(ilk, usr);
        address urn = address(new UrnHandler(joinManager, usr));
        urns[cdpi] = urn;
        owns[cdpi] = usr;
        ilks[cdpi] = ilk;

        emit NewCdp(msg.sender, usr, cdpi);
        return cdpi;
    }

    // Exit a user's gems from the vat.
    function exit(
        uint cdp,
        address gemJoin,
        address usr,
        uint256 amt
    ) public cdpAllowed(cdp) {
        JoinManagerLike(joinManager).exit(
            gemJoin,
            urns[cdp],
            usr,
            amt
        );
    }

    // Frob the cdp keeping the generated DAI or collateral freed in the cdp urn address.
    function frob(
        uint cdp,
        address w,
        int dink,
        int dart
    ) public cdpAllowed(cdp) {
        address urn = urns[cdp];
        JoinManagerLike(joinManager).frob(
            ilks[cdp],
            urn,
            urn,
            w,
            dink,
            dart
        );
    }

    // Transfer wad amount of cdp collateral from the cdp address to a dst address.
    function flux(
        uint cdp,
        address dst,
        uint wad
    ) public cdpAllowed(cdp) {
        JoinManagerLike(joinManager).flux(ilks[cdp], urns[cdp], dst, wad);
    }

    // Quit the system, migrating the cdp (ink, art) to a different dst urn
    function quit(
        uint cdp,
        address dst
    ) public cdpAllowed(cdp) urnAllowed(dst) {
        JoinManagerLike(joinManager).quit(
            ilks[cdp],
            urns[cdp],
            dst
        );
    }
}