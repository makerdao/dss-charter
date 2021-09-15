all     :; dapp --use solc:0.6.12 build
clean   :; dapp clean
test    :; ./test.sh $(match) $(runs)
certora-chartermanagerimp :; certoraRun src/CharterManager.sol:CharterManagerImp certora/DSToken.sol certora/Vat.sol certora/ManagedGemJoin.sol certora/Spotter.sol --link CharterManagerImp:vat=Vat CharterManagerImp:spotter=Spotter ManagedGemJoin:gem=DSToken ManagedGemJoin:vat=Vat --verify CharterManagerImp:certora/CharterManagerImp.spec --rule_sanity
