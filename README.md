## Project overview

We'll make a stablecoin that has those specific traits:

- (Relative Stability): Anchored or pegged to the US Dollar
    - Chainlink Price feed.
    - Set a function to exchange ETH/BTC -> USD
- (Stability mechanism / Minting): Algorithmic (decentralized)
    - People can only mint the stablecoin with enough collateral (coded)
- Collateral: exogenous (crypto)
    - wETH and wBTC (erc 20 versions of ETH & BTC)

## Dependencies

Installed open-zeppelin contracts via: `forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit`

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
