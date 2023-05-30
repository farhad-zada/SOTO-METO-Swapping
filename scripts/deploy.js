// import { ethers, upgrades } from "hardhat";
async function main() {
  const LevelsStaking = await ethers.getContractFactory("LevelsStaking");

  const levelsStaking = await upgrades.deployProxy(LevelsStaking);
  // Start deployment, returning a promise that resolves to a contract object
  await levelsStaking.deployed();
  console.log("Contract deployed to address:", levelsStaking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
