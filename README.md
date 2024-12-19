# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

# Deploy & Verify

## Method 1

```
# bash
> npx hardhat ignition deploy ignition/modules/Token.js --network sepolia --deployment-id nimbus-token-sepolia
> npx hardhat ignition verify nimbus-token-sepolia

> npx hardhat ignition deploy ignition/modules/Staking.js --network sepolia --deployment-id nimbus-staking-sepolia
> npx hardhat ignition verify nimbus-staking-sepolia

```

## Method 2

```
# bash
> npx hardhat ignition deploy ignition/modules/Token.js --network sepolia --verify
> npx hardhat ignition deploy ignition/modules/Staking.js --network sepolia --verify
```
