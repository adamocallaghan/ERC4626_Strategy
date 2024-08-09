-include .env

deploy-vault-to-mode:
	forge create src/Vault.sol:Vault --rpc-url $(MODE_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --constructor-args $(WETH_ADDRESS) "xWrappedEth" "xWETH"

deploy-strategy-to-mode:
	forge create src/Strategy.sol:Strategy --rpc-url $(MODE_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --constructor-args $(WETH_ADDRESS) $(VAULT_ON_MODE)

