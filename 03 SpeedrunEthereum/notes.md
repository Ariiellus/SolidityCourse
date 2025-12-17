# Notes from Speedrun Ethereum projects

## Main concepts

- SE uses hardhat via `yarn start`, `yarn deploy`, and `yarn test` commands for local development.
- When using a testnet env you can generate a new address with `yarn generate`.

## Observations

### Challenge 1 - Decentralized Staking

### Challenge 2 - Token Vendor

- Modifying the contract file name can cause issues with the deployment script.
- Suggestion is contract name and file name should be the same.
- When deploying again the contract use:

  ```bash
  rm -rf packages/hardhat/deployments/localhost packages/hardhat/artifacts packages/hardhat/cache packages/hardhat/typechain-types
  ````

to clear the deployment cache and reduce problems. Docs suggest the use of `yarn deploy --reset` but this does not work for some reason.
