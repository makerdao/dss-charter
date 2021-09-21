// CharterManagerImp.spec

// certoraRun src/CharterManager.sol:CharterManagerImp certora/DSToken.sol certora/Vat.sol certora/ManagedGemJoin.sol certora/Spotter.sol --link CharterManagerImp:vat=Vat CharterManagerImp:spotter=Spotter ManagedGemJoin:gem=DSToken ManagedGemJoin:vat=Vat --verify CharterManagerImp:certora/CharterManagerImp.spec --rule_sanity

using DSToken as token
using Vat as theVat
using ManagedGemJoin as managedGemJoin
using Spotter as theSpotter

methods {
    wards(address) returns (uint256) envfree
    proxy(address) returns (address) envfree
    can(address, address) returns (uint256) envfree
    gate(bytes32) returns (uint256) envfree
    Nib(bytes32) returns (uint256) envfree
    nib(bytes32, address) returns (uint256) envfree
    Peace(bytes32) returns (uint256) envfree
    peace(bytes32, address) returns (uint256) envfree
    uline(bytes32, address) returns uint256 envfree
    vat() returns (address) envfree
    vow() returns (address) envfree
    spotter() returns (address) envfree
    getOrCreateProxy(address) returns (address) envfree
    onLiquidation(address, address, uint256) envfree
    onVatFlux(address, address, address, uint256) envfree

    // Vat methods
    theVat.can(address, address) returns (uint256) envfree
    can(address, address) => DISPATCHER(true)
    theVat.dai(address) returns (uint256) envfree
    dai(address) => DISPATCHER(true)
    theVat.ilks(bytes32) returns (uint256, uint256, uint256, uint256, uint256) envfree
    ilks(bytes32) => DISPATCHER(true)
    theVat.gem(bytes32, address) returns (uint256) envfree
    gem(bytes32, address) => DISPATCHER(true)

    // ManagedGemJoin methods
    managedGemJoin.vat() returns (address) envfree
    managedGemJoin.gem() returns (address) envfree
    managedGemJoin.dec() returns (uint256) envfree
    gem() => DISPATCHER(true)
    managedGemJoin.ilk() returns (bytes32) envfree
    ilk() => DISPATCHER(true)
    join(address, uint256) => DISPATCHER(true)

    // DSToken methods
    token.decimals() returns (uint256) envfree
    transferFrom(address, address, uint256) => DISPATCHER(true)
    approve(address, uint256) => DISPATCHER(true)

    // Spotter methods
    theSpotter.ilks(bytes32) returns (address, uint256) envfree
    // Already dispatched as part of the Vat methods.
    // ilks(bytes32) => DISPATCHER(true)
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

    Peace@withrevert(ilk);
    assert(!lastReverted, "Peace has an unexpected revert condition"); 

    peace@withrevert(ilk, addr1);
    assert(!lastReverted, "peace has an unexpected revert condition"); 

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
    uint256 pre_Peace = Peace(ilk);

    env e;
    file(e, ilk, what, data);

    assert(what == 0x6761746500000000000000000000000000000000000000000000000000000000  // "gate"
               => gate(ilk) == data && Nib(ilk) == pre_Nib && Peace(ilk) == pre_Peace,
           "file did not set gate as expected");
    assert(what == 0x4e69620000000000000000000000000000000000000000000000000000000000  // "Nib"
               => gate(ilk) == pre_gate && Nib(ilk) == data && Peace(ilk) == pre_Peace,
           "file did not set Nib as expected");
    assert(what == 0x5065616365000000000000000000000000000000000000000000000000000000  // "Peace"
               => gate(ilk) == pre_gate && Nib(ilk) == pre_Nib && Peace(ilk) == data,
           "file did not set Peace as expected");
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
                   what != 0x4e69620000000000000000000000000000000000000000000000000000000000   // "Nib"
                   &&
                   what != 0x5065616365000000000000000000000000000000000000000000000000000000;  // "Peace"
    assert(revert3 => lastReverted, "file did not revert for unrecognized what");

    assert(lastReverted => revert1 || revert2 || revert3,
           "file_ilk_revert does not cover all revert conditions");
}

rule file_ilk_usr(bytes32 ilk, address usr, bytes32 what, uint256 data) {
    uint256 pre_uline = uline(ilk, usr);
    uint256 pre_nib = nib(ilk, usr);
    uint256 pre_peace = peace(ilk, usr);

    env e;
    file(e, ilk, usr, what, data);

    assert(what == 0x756c696e65000000000000000000000000000000000000000000000000000000  // "uline"
               => uline(ilk, usr) == data && nib(ilk, usr) == pre_nib && peace(ilk, usr) == pre_peace,
           "file did not set uline as expected");
    assert(what == 0x6e69620000000000000000000000000000000000000000000000000000000000  // "nib"
               => uline(ilk, usr) == pre_uline && nib(ilk, usr) == data && peace(ilk, usr) == pre_peace,
           "file did not set nib as expected");
    assert(what == 0x7065616365000000000000000000000000000000000000000000000000000000  // "peace"
               => uline(ilk, usr) == pre_uline && nib(ilk, usr) == pre_nib && peace(ilk, usr) == data,
           "file did not set peace as expected");
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
                   what != 0x6e69620000000000000000000000000000000000000000000000000000000000   // "nib"
                   &&
                   what != 0x7065616365000000000000000000000000000000000000000000000000000000;  // "peace"
    assert(revert3 => lastReverted, "file did not revert for unrecognized what");

    assert(lastReverted => revert1 || revert2 || revert3,
           "file_ilk_usr_revert does not cover all revert conditions");
}

rule hope(address usr) {
    env e;
    hope(e, usr);
    assert(can(e.msg.sender, usr) == 1, "hope did not set can as expected");
}

rule hope_revert(address usr) {
    env e;
    hope@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "hope did not revert when sent ETH");

    assert(lastReverted => revert1, "hope_revert does not cover all revert conditions");
}

rule nope(address usr) {
    env e;
    nope(e, usr);
    assert(can(e.msg.sender, usr) == 0, "nope did not set can as expected");
}

rule nope_revert(address usr) {
    env e;
    nope@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "nope did not revert when sent ETH");

    assert(lastReverted => revert1, "disallow_revert does not cover all revert conditions");
}

// TODO: figure out how to verify proxy creation case
rule getOrCreateProxy_proxy_already_exists(address usr) {
    address proxyAddr = proxy(usr);
    require(proxyAddr != 0);
    getOrCreateProxy(usr);
    assert(proxyAddr == proxy(usr), "getOrCreatProxy changed the user's proxy unexpectedly");
}

// broken due to overapproximation of 10^k (fixed in staging, remove comment once the fix is pushed to production)
rule join_proxy_already_exists(address gemJoin, address usr, uint256 val) {
    require(vat() == theVat);
    require(token.decimals() == 18);
    require(managedGemJoin.vat() == theVat);
    require(managedGemJoin.gem() == token);
    require(managedGemJoin.dec() == token.decimals());
    require(gemJoin == managedGemJoin);

    address proxyAddr = proxy(usr);
    require(proxyAddr != 0);

    bytes32 ilk = managedGemJoin.ilk();
    uint256 pre_gemBal = theVat.gem(ilk, proxyAddr);

    env e;
    join(e, gemJoin, usr, val);

    uint256 post_gemBal = theVat.gem(ilk, proxyAddr);
    assert(post_gemBal == pre_gemBal + val, "join did not add collateral as expected");
}

// TODO: exit spec, skipping for now b/c probably affected by same bug as join spec

rule frob_proxy_already_exists_w_not_vow_or_proxy(address u, address v, address w, int256 dink, int256 dart) {
    require(vat() == theVat);
    require(spotter() == theSpotter);
    require(token.decimals() == 18);
    require(managedGemJoin.vat() == theVat);
    require(managedGemJoin.gem() == token);
    require(managedGemJoin.dec() == token.decimals());

    address proxyAddr = proxy(u);
    require(proxyAddr != 0);
    require(proxyAddr != w);
    
    bytes32 ilk = managedGemJoin.ilk();
    uint256 _gate = gate(ilk);
    uint256 _nib = _gate == 1 ? nib(ilk, u) : Nib(ilk);

    address _vow = vow();
    require(_vow != w);

    uint256 preVowDai = theVat.dai(_vow);
    uint256 preWDai = theVat.dai(w);
    uint256 preProxyDai = theVat.dai(proxyAddr);
    uint256 preProxyGem = theVat.gem(ilk, proxyAddr);

    uint256 util1; uint256 util2; uint256 util3; uint256 util4;
    uint256 rate;
    util1, rate, util2, util3, util4 = theVat.ilks(ilk);
    require(rate >= 10^27);  // satisfied in real contracts, and out-of-scope here anyway

    env e;
    frob(e, ilk, u, v, w, dink, dart);

    // dai assertions are conditional on whether any origination fee applies
    mathint dtab = rate * to_mathint(dart);
//    mathint coin = (dart > 0 && _nib > 0) ? dtab * _nib / 10^18 : 0;
//    assert(theVat.dai(_vow) == preVowDai + coin, "origination fee not sent to the Vow");
//    assert(theVat.dai(w) == preWDai + dtab - coin, "dai drawn not sent to destination");
    assert(theVat.dai(_vow) >= preVowDai);
    if (dart > 0) {
        assert(theVat.dai(w) >= preWDai, "dai of destination should not decrease if dart > 0");
        assert(theVat.dai(w) <= preWDai + dtab, "dai of destination should not increase by more than dtab if dart > 0");
    } else {
        assert(theVat.dai(w) == preWDai + dtab, "dai drawn not sent to destination");
    }
    assert(theVat.dai(proxyAddr) == preProxyDai, "proxy dai changed unexpectedly");

    // gem assertions    
    assert(theVat.gem(ilk, proxyAddr) == preProxyGem - to_mathint(dink), "proxy gem not modified as expected");    
}

rule flux_proxies_already_exist_distinct_addresses(bytes32 ilk, address src, address dst, uint256 wad) {
    require(vat() == theVat);
    address srcProxyAddr = proxy(src);
    require(srcProxyAddr != 0);
    address dstProxyAddr = proxy(dst);
    require(dstProxyAddr != 0);
    require(srcProxyAddr != dstProxyAddr);  // should imply src != dst

    uint256 srcPreGemBal = theVat.gem(ilk, srcProxyAddr);
    uint256 dstPreGemBal = theVat.gem(ilk, dstProxyAddr);

    env e;
    flux(e, ilk, src, dst, wad);

    uint256 srcPostGemBal = theVat.gem(ilk, srcProxyAddr);
    uint256 dstPostGemBal = theVat.gem(ilk, dstProxyAddr);

    assert(srcPostGemBal == srcPreGemBal - wad, "src gem balance not modified correctly");   
    assert(dstPostGemBal == dstPreGemBal + wad, "dst gem balance not modified correctly");   
}

rule flux_proxies_already_exist_identical_addresses(bytes32 ilk, address usr, uint256 wad) {
    require(vat() == theVat);
    address proxyAddr = proxy(usr);
    require(proxyAddr != 0);

    uint256 preGemBal = theVat.gem(ilk, proxyAddr);

    env e;
    flux(e, ilk, usr, usr, wad);

    uint256 postGemBal = theVat.gem(ilk, proxyAddr);

    assert(postGemBal == preGemBal, "gem balance modified unexpectedly");   
}

rule flux_proxies_already_exist_distinct_addresses_revert(bytes32 ilk, address src, address dst, uint256 wad) {
    require(vat() == theVat);
    address srcProxyAddr = proxy(src);
    require(srcProxyAddr != 0);
    address dstProxyAddr = proxy(dst);
    require(dstProxyAddr != 0);
    require(srcProxyAddr != dstProxyAddr);  // should imply src != dst

    uint256 srcPreGemBal = theVat.gem(ilk, srcProxyAddr);
    uint256 dstPreGemBal = theVat.gem(ilk, dstProxyAddr);

    env e;
    bool allowed = src == e.msg.sender || can(src, e.msg.sender) == 1;
    bool allowedVat = srcProxyAddr == currentContract || theVat.can(srcProxyAddr, currentContract) == 1;
    flux@withrevert(e, ilk, src, dst, wad);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "flux did not revert when sent ETH");

    bool revert2 = !allowed;
    assert(revert2 => lastReverted, "flux did not revert when caller was unauthorized");

    bool revert3 = !allowedVat;
    assert(revert3 => lastReverted, "flux did not revert when Vat authorization was absent");

    bool revert4 = srcPreGemBal < wad;
    assert(revert4 => lastReverted, "flux did not revert when src balance underflowed");

    bool revert5 = (2^256 - 1) - wad < dstPreGemBal;
    assert(revert5 => lastReverted, "flux did not revert when dst balance overflowed");

    assert(lastReverted => revert1 || revert2 || revert3 || revert4 || revert5,
           "flux_proxies_already_exist_distinct_addresses_revert does not cover all revert conditions");
}

rule flux_proxies_already_exist_identical_addresses_revert(bytes32 ilk, address usr, uint256 wad) {
    require(vat() == theVat);
    address proxyAddr = proxy(usr);
    require(proxyAddr != 0);

    uint256 preGemBal = theVat.gem(ilk, proxyAddr);

    env e;
    bool allowed = usr == e.msg.sender || can(usr, e.msg.sender) == 1;
    bool allowedVat = proxyAddr == currentContract || theVat.can(proxyAddr, currentContract) == 1;
    flux@withrevert(e, ilk, usr, usr, wad);

    bool revert1 = e.msg.value > 0;
    assert(revert1 => lastReverted, "flux did not revert when sent ETH");

    bool revert2 = !allowed;
    assert(revert2 => lastReverted, "flux did not revert when caller was unauthorized");

    bool revert3 = !allowedVat;
    assert(revert3 => lastReverted, "flux did not revert when Vat authorization was absent");

    bool revert4 = preGemBal < wad;
    assert(revert4 => lastReverted, "flux did not revert when src balance underflowed");

    assert(lastReverted => revert1 || revert2 || revert3 || revert4,
           "flux_proxies_already_exist_identical_addresses_revert does not cover all revert conditions");
}