// import { ethers, upgrades } from "hardhat";
async function main() {
  const SocialToken = await ethers.getContractFactory("SocialToken");

  const socialToken = await upgrades.deployProxy(SocialToken);
  // Start deployment, returning a promise that resolves to a contract object
  await socialToken.deployed();
  console.log("Contract deployed to address:", socialToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
