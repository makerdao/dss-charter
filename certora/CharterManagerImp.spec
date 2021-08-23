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
