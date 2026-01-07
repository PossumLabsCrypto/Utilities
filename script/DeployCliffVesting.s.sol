// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {CliffVesting} from "src/CliffVesting.sol";

contract DeployCliffVesting is Script {
    function setUp() public {}

    address owner = 0xAC23698691311E2cD7A3993806745c06Ccb58384;
    uint256 unlockTime = 1762838999; // Nov-11-2024

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        CliffVesting cliffVesting = new CliffVesting(owner, unlockTime);
        deployedAddress = address(cliffVesting);

        vm.stopBroadcast();
    }
}

// forge script script/DeployCliffVesting.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ARBISCAN_API_KEY --optimize --optimizer-runs 1000
