// import { ethers, upgrades } from "hardhat";
//TODO: to run this script uncomment above code
async function main() {
  const SwappingMetoSoto = await ethers.getContractFactory("SwappingMetoSoto");

  const swappingMetoSoto = await upgrades.deployProxy(SwappingMetoSoto);
  // Start deployment, returning a promise that resolves to a contract object
  await swappingMetoSoto.deployed();
  console.log("Contract deployed to address:", swappingMetoSoto.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
