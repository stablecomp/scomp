import { execSync } from "child_process";

function executeCommand(command: string): void {
  try {
    execSync(command, { stdio: "inherit" });
  } catch (error: any) {
    console.error("Error in command:", error);
    process.exit(1);
  }
}

function main(): void {
  console.log(`\n=== Starting Ethereum Token Deployment ===`);
  executeCommand("npx hardhat run scripts/ethereum/deploy.ts --network goerli");

  console.log(`\n=== Starting Polygon Token Deployment ===`);
  executeCommand(
    "npx hardhat run scripts/polygon/deploy.ts --network polygonMumbai"
  );
}

main();
