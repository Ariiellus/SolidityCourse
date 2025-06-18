## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


---

For deployment, use:

`forge create <contrato> --interactive --broadcast`
or
`forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY <contrato> broadcast`

// For verification, use:
// `forge verify-contract <contract_address> SimpleStorage --chain-id <chain_id>`


Use forge script script/DeploySimpleStorage.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY to deploy the contract

$RPC_URL & $PRIVATE_KEY are in the .env file

NOTE: Learn how to encrypt private keys and use instead a keystore file with a password!!!

Update: 

//Use cast wallet import <name> --interactive to encrypt your private key and add a password to it.

//Use forge script script/DeploySimpleStorage.s.sol --rpc-url $RPC_URL --broadcast --account testKey --sender $SENDER_KEY -vvvv to deploy the contract with a encrypted private key.

For deploy a local zksync node use: anvil-zksync