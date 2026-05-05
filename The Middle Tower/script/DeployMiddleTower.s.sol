// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MiddleTower.sol";

/**
 * @title DeployMiddleTower
 * @dev Deployment script for Polygon Amoy Testnet
 */
contract DeployMiddleTower is Script {
    function run() external {
        // Fetch environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Pre-defined Aryana Island contract address
        address islandAddress = 0x0476985334f93524DE24743D028e6E257498C1ef;

        // Start recording transactions for broadcasting to the network
        vm.startBroadcast(deployerPrivateKey);

        // Initialize MiddleTower with deployer as owner
        MiddleTower tower = new MiddleTower(deployerAddress, islandAddress);

        // Set the global collection metadata
        tower.setContractURI("ipfs://bafkreiei6wf7zsokbqkmbetj5f47zhhwiepbxvakxx2xhobo5fjm4yfdsi");

        vm.stopBroadcast();

        // Print deployment details to terminal
        console.log("-----------------------------------------");
        console.log("Deployment Successful!");
        console.log("Middle Tower Address:", address(tower));
        console.log("Owner Address:       ", deployerAddress);
        console.log("-----------------------------------------");
    }
}
