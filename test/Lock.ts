import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

import { CarRent, TokenFarm } from "../typechain-types";
import { fromWei, toWei } from "../utils";

const _checkClaim = async (
  contract: TokenFarm,
  token: CarRent,
  user: Signer
) => {
  const [owner] = await ethers.getSigners();
  const beforeUserTokenBal = await token.balanceOf(await user.getAddress());
  const beforeContractBal = await token.balanceOf(contract.target);
  const claimableReward = await contract.claimableRewards(
    await user.getAddress()
  );
  if (claimableReward == 0n) {
    expect(await contract.connect(user).claimRewards()).to.be.revertedWith(
      "No rewards available"
    );
    return;
  }
  (await contract.connect(user).claimRewards()).wait();
  const afterUserTokenBal = await token.balanceOf(await user.getAddress());
  const afterContractBal = await token.balanceOf(contract.target);
  expect(afterUserTokenBal).to.eq(claimableReward + beforeUserTokenBal);
  expect(afterContractBal).to.eq(beforeContractBal - claimableReward);
};

const _checkEthClaim = async (contract: TokenFarm, user: Signer) => {
  const beforeUserEthBal = await ethers.provider.getBalance(
    await user.getAddress()
  );
  const claimableEthReward = await contract.claimableETHReward(
    await user.getAddress()
  );
  if (claimableEthReward == 0n) {
    expect(await contract.connect(user).claimETHReward()).to.be.revertedWith(
      "No rewards available"
    );
    return;
  }
  const tx = await (await contract.connect(user).claimETHReward()).wait();
  const afterUserEthBal = await ethers.provider.getBalance(
    await user.getAddress()
  );
  expect(afterUserEthBal).to.eq(
    beforeUserEthBal +
      claimableEthReward -
      (tx?.gasUsed ?? 0n) * (tx?.gasPrice ?? 0n)
  );
};

describe("Should test the lexa contract", () => {
  const ownerAddress = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199";
  let token: CarRent;
  let lexa: TokenFarm;

  it("Should deploy the token and lexa contract and create a pool", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    const tokenFactory = await ethers.getContractFactory("CarRent");
    const tokenContract = await tokenFactory.connect(owner).deploy();
    await tokenContract.waitForDeployment();

    const lexaFactory = await ethers.getContractFactory("TokenFarm");
    const lexaContract = await lexaFactory
      .connect(owner)
      .deploy(tokenContract.target, tokenContract.target);
    await lexaContract.waitForDeployment();

    const addPool = await lexaContract
      .connect(owner)
      .addPool(toWei(1e8), toWei(1e6), 50, toWei(100), 100, 10, true, true);
    await addPool.wait();

    token = tokenContract;
    lexa = lexaContract;

    const pool = await lexa.pool();

    // transfer tokens to users
    (await token.connect(owner).transfer(user1.address, toWei(1000))).wait();
    (await token.connect(owner).transfer(user2.address, toWei(1000))).wait();
    (await token.connect(owner).transfer(user3.address, toWei(1000))).wait();

    // users balance
    const balance = await token.balanceOf(user1.address);
    console.log("balance: ", balance);
    const balance2 = await token.balanceOf(user2.address);
    console.log("balance2: ", balance2);
    const balance3 = await token.balanceOf(user3.address);
    console.log("balance3: ", balance3);

    // token wallet should approve lexa contract
    (await token.approve(lexa.target, toWei(1e7))).wait();
    await (await token.transfer(lexa.target, toWei(1e4))).wait();
  });

  it("Should staked by user", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    (await token.connect(user1).approve(lexa.target, toWei(1000))).wait();
    (await token.connect(user2).approve(lexa.target, toWei(1000))).wait();
    (await token.connect(user3).approve(lexa.target, toWei(1000))).wait();

    (await lexa.connect(user1).stakeTokens(toWei(100))).wait();
    (await lexa.connect(user2).stakeTokens(toWei(100))).wait();
    (await lexa.connect(user3).stakeTokens(toWei(100))).wait();

    const user1Bal = await lexa.userInfo(user1.address);
    console.log("user1Bal: ", user1Bal);
    const user2Bal = await lexa.userInfo(user2.address);
    console.log("user2Bal: ", user2Bal);
  });

  it("Should increase time by 2 day", async function () {
    await time.increase(10 * 86400);
  });

  it("Should add reward and check reward is available", async function () {
    const [owner, user1, user2] = await ethers.getSigners();

    const addReward = await lexa.connect(owner).addReward(toWei(100));
    await addReward.wait();

    const reward = await lexa.claimableRewards(user1.address);
    const reward2 = await lexa.claimableRewards(user2.address);
    console.log("reward: ", reward);
    console.log("reward2: ", fromWei(reward2));
  });

  it("Should claim reward", async function () {
    const [owner, user1, user2] = await ethers.getSigners();
    await _checkClaim(lexa, token, user1);
    await _checkClaim(lexa, token, user2);
  });

  it("Should stake more tokens by user", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    await (await lexa.connect(user1).stakeTokens(toWei(100))).wait();
    await (await lexa.connect(user2).stakeTokens(toWei(100))).wait();
    // await (await lexa.connect(user3).stakeTokens(toWei(100))).wait();
  });

  it("Should add the eth reward", async function () {
    const [owner, user1, user2] = await ethers.getSigners();
    const addEthReward = await lexa
      .connect(owner)
      .addETHReward({ value: toWei(9) });
    await addEthReward.wait();
  });

  it("should increase the time", async function () {
    await time.increase(10 * 86400);
  });

  it("Should claim the eth reward", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();
    const claimableEthRewardUser1 = await lexa.claimableETHReward(
      user1.address
    );
    console.log("claimableEthRewardUser1: ", fromWei(claimableEthRewardUser1));
    const claimableEthRewardUser2 = await lexa.claimableETHReward(
      user2.address
    );
    console.log("claimableEthRewardUser2: ", fromWei(claimableEthRewardUser2));
    const claimableEthRewardUser3 = await lexa.claimableETHReward(
      user3.address
    );
    console.log("claimableEthRewardUser2: ", fromWei(claimableEthRewardUser3));

    await _checkEthClaim(lexa, user1);
    await _checkEthClaim(lexa, user2);
    await _checkEthClaim(lexa, user3);
  });

  it("Should be able to unstake", async function () {
    const [owner, user1, user2, user3] = await ethers.getSigners();
    await (await lexa.connect(user1).unstakeTokens()).wait();
    await (await lexa.connect(user2).unstakeTokens()).wait();
    await (await lexa.connect(user3).unstakeTokens()).wait();
  });
});
