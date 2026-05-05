// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AryanaIsland.sol";

contract DeployAryana is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        AryanaIsland island = new AryanaIsland(deployerAddress);

        string memory islandURI =
            "ipfs://bafkreihyowxudgomj6y5muwhmnv3iznn6yldccwc4cwn3wauscir5yu2um";

        island.initializeIsland(deployerAddress, islandURI);

        vm.stopBroadcast();

        console.log("-----------------------------------------");
        console.log("Aryana Island Deployed at:", address(island));
        console.log("Owner Address:", deployerAddress);
        console.log("Symbol: ARYANA");
        console.log("-----------------------------------------");
    }
}
