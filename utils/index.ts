import { ethers } from "hardhat"

export const toWei = (value: number, decimal: number = 18) => {
  return ethers.parseUnits(value.toString(), decimal);
}

export const fromWei = (value: bigint, decimal: number = 18) => {
  return ethers.formatUnits(value, decimal);
}