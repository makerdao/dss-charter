all     :; dapp --use solc:0.6.12 build
clean   :; dapp clean
test    :; ./test.sh $(match) $(runs)
certora-chartermanagerimp :; certoraRun src/CharterManager.sol:CharterManagerImp --verify CharterManagerImp:certora/CharterManagerImp.spec --rule_sanity
