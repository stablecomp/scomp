import { ethers } from "hardhat";
import hre from "hardhat";
import { Signer, ContractFactory, Contract } from "ethers";

const ethereumEndpointAddress = "0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675";
const polygonEndpointAddress = "0x3c2269811836af69497E5F486A85D7316753cf62";

const ethereumChainId = 101;
const polygonChainId = 109;

class Deployer {
  private account: Signer;
  private accountAddress: string;
  private gasPrice: string;
  private balance: string;
  private lzEndpoint: string;
  private token: Contract | null;
  private vesting: Contract | null;

  constructor(account: Signer) {
    this.account = account;
    this.accountAddress = "";
    this.gasPrice = "";
    this.balance = "";
    this.lzEndpoint = polygonEndpointAddress; //TODO: change to Polygon mainnet
    this.token = null;
    this.vesting = null;
  }

  async initialize(): Promise<void> {
    this.accountAddress = await this.account.getAddress();
    this.gasPrice = ethers.utils.formatUnits(
      await ethers.provider.getGasPrice(),
      "gwei"
    );
    this.balance = ethers.utils.formatEther(await this.account.getBalance());
    console.log(
      `\Polygon Deployer Initialized. \nAccount: ${this.accountAddress} \nBalance: ${this.balance} \nGas Price: ${this.gasPrice} Gwei`
    );
  }

  async deployToken(): Promise<void> {
    console.log("\nDeploying Stablecomp token to Polygon...");
    const factoryToken: ContractFactory = await ethers.getContractFactory(
      "Stablecomp"
    );
    const token: Contract = await factoryToken.deploy(
      this.accountAddress,
      this.lzEndpoint
    );
    const txHash = token.deployTransaction.hash;
    console.log(`Transaction started with hash: ${txHash}`);
    await token.deployTransaction.wait();
    await token.deployed();
    console.log(`Contract deployed to: ${token.address}`);
    this.token = token;
  }

  async verifyContract(): Promise<void> {
    console.log("Waiting 1 minute before verification...");
    await new Promise((resolve) => setTimeout(resolve, 60000));

    console.log("\nVerifying Stablecomp token on Polygon...");
    await hre.run("verify:verify", {
      address: this.token?.address,
      constructorArguments: [this.accountAddress, this.lzEndpoint],
    });
    console.log("Contract verified!");
  }
}

async function main(): Promise<void> {
  const accounts: Signer[] = await ethers.getSigners();
  const deployer: Deployer = new Deployer(accounts[0]);
  await deployer.initialize();

  try {
    await deployer.deployToken();

    await deployer.verifyContract();
    console.log("\n=== Polygon Token Deployment Completed Successfully ===");
  } catch (error: any) {
    console.error(`\n!!! Error in Polygon Token Deployment:`, error.message);
    process.exitCode = 1;
  }
}

main().catch((error: any) => {
  console.error("\n!!! Unhandled Error:", error.message);
  process.exitCode = 1;
});
