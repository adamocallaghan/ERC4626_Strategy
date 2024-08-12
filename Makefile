-include .env

deploy-vault-to-mode:
	forge create src/Vault.sol:Vault --rpc-url $(MODE_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --constructor-args $(WETH_ADDRESS) "xWrappedEth" "xWETH"

deploy-strategy-to-mode:
	forge create src/Strategy.sol:Strategy --rpc-url $(MODE_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --constructor-args $(WETH_ADDRESS) $(VAULT_ON_MODE)

verify-mode-vault:
	forge verify-contract --chain-id 919 $(VAULT_ON_MODE) src/Vault.sol:Vault --constructor-args-path vault-constructor-args.txt --verifier blockscout --verifier-url https://sepolia.explorer.mode.network/api\?

verify-mode-strategy:
	forge verify-contract --chain-id 919 $(STRATEGY_ON_MODE) src/Strategy.sol:Strategy --constructor-args-path strategy-constructor-args.txt --verifier blockscout --verifier-url https://sepolia.explorer.mode.network/api\?