// CharterManagerImp.spec

// certoraRun src/CharterManager.sol:CharterManagerImp --verify CharterManagerImp:certora/CharterManagerImp.spec --rule_sanity

methods {
    wards(address) returns (uint256) envfree
    proxy(address) returns (address) envfree
    can(address, address) returns (uint256) envfree
    gate(bytes32) returns (uint256) envfree
    Nib(bytes32) returns (uint256) envfree
    nib(bytes32, address) returns uint256 envfree
    uline(bytes32, address) returns uint256 envfree
    vat() returns (address) envfree
    vow() returns (address) envfree
    getOrCreateProxy(address) returns (address) envfree
    onLiquidation(address, address, uint256) envfree
    onVatFlux(address, address, address, uint256) envfree
}

// Confirm no unexpected reversion cases for envfree functions.
// Certora will check the msg.value != 0 case automatically.
rule envfree_funcs_no_unexpected_reverts(address addr1, address addr2, address addr3, bytes32 ilk, uint256 wad) {
    wards@withrevert(addr1);
    assert(!lastReverted, "wards has an unexpected revert condition"); 

    proxy@withrevert(addr1);
    assert(!lastReverted, "proxy has an unexpected revert condition"); 

    can@withrevert(addr1, addr2);
    assert(!lastReverted, "can has an unexpected revert condition"); 

    gate@withrevert(ilk);
    assert(!lastReverted, "can has an unexpected revert condition"); 

    Nib@withrevert(ilk);
    assert(!lastReverted, "Nib has an unexpected revert condition"); 

    nib@withrevert(ilk, addr1);
    assert(!lastReverted, "nib has an unexpected revert condition"); 

    uline@withrevert(ilk, addr1);
    assert(!lastReverted, "uline has an unexpected revert condition"); 

    vat@withrevert();
    assert(!lastReverted, "vat has an unexpected revert condition"); 

    vow@withrevert();
    assert(!lastReverted, "vow has an unexpected revert condition"); 

// Broken at the moment--need help from Certora team.
//    getOrCreateProxy@withrevert(addr1);
//    assert(!lastReverted, "getOrCreateProxy has an unexpected revert condition"); 

    onLiquidation@withrevert(addr1, addr2, wad);
    assert(!lastReverted, "onLiquidation has an unexpected revert condition"); 

    onVatFlux@withrevert(addr1, addr2, addr3, wad);
    assert(!lastReverted, "onVatFlux has an unexpected revert condition"); 
}

rule file_ilk(bytes32 ilk, bytes32 what, uint256 data) {
    uint256 pre_gate = gate(ilk);
    uint256 pre_Nib = Nib(ilk);

    env e;
    file(e, ilk, what, data);

    assert(what == 0x6761746500000000000000000000000000000000000000000000000000000000
               => gate(ilk) == data && Nib(ilk) == pre_Nib,
           "file did not set gate as expected");
    assert(what == 0x4e69620000000000000000000000000000000000000000000000000000000000
               => gate(ilk) == pre_gate && Nib(ilk) == data,
           "file did not set Nib as expected");
}

rule file_ilk_revert(bytes32 ilk, bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);

    file@withrevert(e, ilk, what, data);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "file did not revert when sent ETH");

    bool revert2 = ward != 1;
    assert(revert2 => lastReverted, "file did not revert for unauthorized msg.sender");

    bool revert3 = what != 0x6761746500000000000000000000000000000000000000000000000000000000   // "gate"
                   &&
                   what != 0x4e69620000000000000000000000000000000000000000000000000000000000;  // "Nib"
    assert(revert3 => lastReverted, "file did not revert for unrecognized what");

    assert(lastReverted => revert1 || revert2 || revert3,
           "file_ilk_revert does not cover all revert conditions");
}

rule file_ilk_usr(bytes32 ilk, address usr, bytes32 what, uint256 data) {
    uint256 pre_uline = uline(ilk, usr);
    uint256 pre_nib = nib(ilk, usr);

    env e;
    file(e, ilk, usr, what, data);

    assert(what == 0x756c696e65000000000000000000000000000000000000000000000000000000  // "uline"
               => uline(ilk, usr) == data && nib(ilk, usr) == pre_nib, 
           "file did not set uline as expected");
    assert(what == 0x6e69620000000000000000000000000000000000000000000000000000000000  // "nib"
               => uline(ilk, usr) == pre_uline && nib(ilk, usr) == data,
           "file did not set nib as expected");
}

rule file_ilk_usr_revert(bytes32 ilk, address usr, bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);

    file@withrevert(e, ilk, usr, what, data);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "file did not revert when sent ETH");

    bool revert2 = ward != 1;
    assert(revert2 => lastReverted, "file did not revert for unauthorized msg.sender");

    bool revert3 = what != 0x756c696e65000000000000000000000000000000000000000000000000000000   // "uline"
                   &&
                   what != 0x6e69620000000000000000000000000000000000000000000000000000000000;  // "nib"
    assert(revert3 => lastReverted, "file did not revert for unrecognized what");

    assert(lastReverted => revert1 || revert2 || revert3,
           "file_ilk_usr_revert does not cover all revert conditions");
}
