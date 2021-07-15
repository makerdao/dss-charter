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

interface VatLike {
    function live() external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function dai(address) external view returns (uint256);
    function fork(bytes32, address, address, int256, int256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function flux(bytes32, address, address, uint256) external;
    function move(address, address, uint256) external;
    function hope(address) external;
    function nope(address) external;
    function ilks(bytes32) external view returns (
        uint256 Art,  // [wad]
        uint256 rate, // [ray]
        uint256 spot, // [ray]
        uint256 line, // [rad]
        uint256 dust  // [rad]
    );
}

interface ManagedGemJoinLike {
    function gem() external view returns (address);
    function ilk() external view returns (bytes32);
    function join(address, uint256) external;
    function exit(address, address, uint256) external;
}

interface TokenLike {
    function approve(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

contract UrnProxy {
    address immutable public usr;

    constructor(address vat_, address usr_) public {
        usr = usr_;
        VatLike(vat_).hope(msg.sender);
    }
}

contract CharterManager {
    mapping (address => uint256) public wards;
    address public implementation;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event SetImplementation(address indexed);

    constructor() public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(msg.sender);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(msg.sender);
    }

    modifier auth {
        require(wards[msg.sender] == 1, "CharterManager/non-authed");
        _;
    }

    function setImplementation(address implementation_) external auth {
        implementation = implementation_;
        emit SetImplementation(implementation_);
    }

    fallback() external {
        address _impl = implementation;
        require(_impl != address(0));

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

contract CharterManagerImp {
    // --- Data ---
    mapping (address => uint256) public wards;
    bytes32 slot1;
    mapping (address => address) public proxy; // UrnProxy per user
    mapping (address => mapping (address => uint256)) public can;

    mapping (bytes32 => uint256)                     public gate; // allow only permissioned vaults
    mapping (bytes32 => uint256)                     public Nib;  // fee percentage for un-permissioned vaults [wad]
    mapping (bytes32 => mapping(address => uint256)) public nib;  // fee percentage for permissioned vaults    [wad]
    mapping (bytes32 => mapping(address => uint256)) public line; // debt ceiling for permissioned vaults      [rad]

    address public immutable vat;
    address public immutable vow;

    // --- Administration ---
    event File(bytes32 indexed ilk, bytes32 indexed what, bool data);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 data);
    event File(bytes32 indexed ilk, address indexed user, bytes32 indexed what, uint256 data);
    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        if (what == "gate") gate[ilk] = data;
        else if (what == "Nib") Nib[ilk] = data;
        else revert("CharterManager/file-unrecognized-param");
        emit File(ilk, what, data);
    }
    function file(bytes32 ilk, address user, bytes32 what, uint256 data) external auth {
        if (what == "line") line[ilk][user] = data;
        else if (what == "nib") nib[ilk][user] = data;
        else revert("CharterManager/file-unrecognized-param");
        emit File(ilk, user, what, data);
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, y) / WAD;
    }

    // --- Auth ---
    modifier auth { require(wards[msg.sender] == 1, "CharterManager/non-authed"); _; }

    constructor(address vat_, address vow_) public {
        vat = vat_;
        vow = vow_;
    }

    event Allow(address indexed from, address indexed to);
    event Disallow(address indexed from, address indexed to);
    modifier allowed(address usr) {
        require(msg.sender == usr || can[usr][msg.sender] == 1, "CharterManager/not-allowed");
        _;
    }
    function allow(address usr) external {
        can[msg.sender][usr] = 1;
        emit Allow(msg.sender, usr);
    }
    function disallow(address usr) external {
        can[msg.sender][usr] = 0;
        emit Disallow(msg.sender, usr);
    }

    function getOrCreateProxy(address usr) public returns (address urp) {
        urp = proxy[usr];
        if (urp == address(0)) {
            urp = proxy[usr] = address(new UrnProxy(address(vat), usr));
        }
    }

    function join(address gemJoin, address usr, uint256 val) external {
        TokenLike(ManagedGemJoinLike(gemJoin).gem()).transferFrom(msg.sender, address(this), val);
        TokenLike(ManagedGemJoinLike(gemJoin).gem()).approve(gemJoin, val);
        ManagedGemJoinLike(gemJoin).join(getOrCreateProxy(usr), val);
    }

    function exit(address gemJoin, address usr, uint256 val) external {
        address urp = proxy[msg.sender];
        require(urp != address(0), "CharterManager/non-existing-urp");
        ManagedGemJoinLike(gemJoin).exit(urp, usr, val);
    }

    function frob(address gemJoin, address u, address v, address w, int256 dink, int256 dart) external allowed(u) {
        require(u == v && w == msg.sender, "CharterManager/not-matching");
        address urp = getOrCreateProxy(u);

        bytes32 ilk = ManagedGemJoinLike(gemJoin).ilk();
        uint256 _gate = gate[ilk];
        uint256 _nib = (_gate == 1) ? nib[ilk][u] : Nib[ilk];

        uint256 rate;
        if (dart > 0 && (_nib > 0 || _gate == 1)) {
            (,rate,,,) = VatLike(vat).ilks(ilk);
        }

        if (dart > 0 && _nib > 0) {
            uint256 dtab = mul(rate, uint256(dart)); // rad
            uint256 coin = wmul(dtab, _nib);         // rad

            VatLike(vat).frob(ilk, urp, urp, urp, dink, dart);
            VatLike(vat).move(urp, w, sub(dtab, coin));
            VatLike(vat).move(urp, vow, coin);
        } else {
            VatLike(vat).frob(ilk, urp, urp, w, dink, dart);
        }

        if (dart > 0 && _gate == 1) {
            (, uint256 art) = VatLike(vat).urns(ilk, urp);
            require(mul(art, rate) <= line[ilk][u], "CharterManager/user-line-exceeded");
        }
    }

    function flux(address gemJoin, address src, address dst, uint256 wad) external allowed(src) {
        address surp = getOrCreateProxy(src);
        address durp = getOrCreateProxy(dst);

        VatLike(vat).flux(ManagedGemJoinLike(gemJoin).ilk(), surp, durp, wad);
    }

    function onLiquidation(address gemJoin, address usr, uint256 wad) external {}

    function onVatFlux(address gemJoin, address from, address to, uint256 wad) external {}

    function quit(bytes32 ilk, address dst) external {
        require(VatLike(vat).live() == 0, "CharterManager/vat-still-live");

        address urp = getOrCreateProxy(msg.sender);
        (uint256 ink, uint256 art) = VatLike(vat).urns(ilk, urp);
        require(int256(ink) >= 0, "CharterManager/overflow");
        require(int256(art) >= 0, "CharterManager/overflow");
        VatLike(vat).fork(
            ilk,
            urp,
            dst,
            int256(ink),
            int256(art)
        );
    }
}