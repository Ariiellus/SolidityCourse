
# Proveably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. Users should be able to enter the raffle by paying for a ticket. The ticket fees are going to be the prize the winner receives.
2. The lottery should automatically and programmatically draw a winner after a certain period.
3. Chainlink VRF should generate a provably random number.

4. Chainlink Automation should trigger the lottery draw regularly.

## Notes

1. Helper contracts allows to select in which chain will be deployed the lottery. Right now only Anvil & Sepolia are supported.

2. Chainlink VRF Mocks are configured according Anvil / Sepolia. I need to study more about Mocks.
