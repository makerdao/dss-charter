pragma solidity >=0.6.12;

interface VatLike {
    function slip(bytes32, address, int256) external;
}

interface GemLike {
    function decimals() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

// For a token that needs join/exit to be managed (like in permissioned vaults)

contract ManagedGemJoin {
    VatLike public immutable vat;
    bytes32 public immutable ilk;
    GemLike public immutable gem;
    uint256 public immutable dec;
    uint256 public live;  // Access Flag

    // --- Auth ---
    mapping (address => uint256) public wards;

    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth { require(wards[msg.sender] == 1, "ManagedGemJoin/non-authed"); _; }

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Join(address indexed urn, uint256 amt);
    event Exit(address indexed urn, address indexed usr, uint256 amt);
    event Cage();

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
        gem = GemLike(gem_);
        dec = GemLike(gem_).decimals();
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function cage() external auth {
        live = 0;
        emit Cage();
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ManagedGemJoin/overflow");
    }

    function join(address urn, uint256 amt) public auth {
        require(live == 1, "ManagedGemJoin/not-live");
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(wad <= (2 ** 255 - 1), "ManagedGemJoin/overflow");
        vat.slip(ilk, urn, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), amt), "ManagedGemJoin/failed-transfer");
        emit Join(urn, amt);
    }

    function exit(address urn, address usr, uint256 amt) public auth {
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(wad <= 2 ** 255, "ManagedGemJoin/overflow");
        vat.slip(ilk, urn, -int256(wad));
        require(gem.transfer(usr, amt), "ManagedGemJoin/failed-transfer");
        emit Exit(urn, usr, amt);
    }
}
