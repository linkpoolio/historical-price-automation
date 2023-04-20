-include .env

install:
	forge install --no-git smartcontractkit/chainlink

deploy:
	forge script script/HistoricalPriceScript.s.sol:HistoricalPriceScript --rpc-url ${RPC_URL} --etherscan-api-key ${EXPLORER_KEY} --broadcast --verify -vvvv

clean:
	rm -rf lib
	
# tests
test-contracts-all:
	forge test -vvvvv

