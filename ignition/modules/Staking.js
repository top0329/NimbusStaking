const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const StakingModule = buildModule("StakingModule", (m) => {
    // Replace these addresses with the actual token addresses
    const tokenAddress = '0xe97B57A354CED06E90F35833306Cb8849904E168';
    const rewardTokenAddress = '0xe97B57A354CED06E90F35833306Cb8849904E168';

    const staking = m.contract("Staking", [tokenAddress, rewardTokenAddress]);

    return { staking };
});

module.exports = StakingModule;