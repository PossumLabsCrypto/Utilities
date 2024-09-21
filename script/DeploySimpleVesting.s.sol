// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {SimpleVesting} from "src/SimpleVesting.sol";

contract DeploySimpleVesting is Script {
    function setUp() public {}

    address beneficiary = 0xAC23698691311E2cD7A3993806745c06Ccb58384;
    uint256 unlockTime = 1762838999; // Nov-11-2024

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        // Configure optimizer settings
        vm.store(address(this), bytes32("optimizer"), bytes32("true"));
        vm.store(address(this), bytes32("optimizerRuns"), bytes32(uint256(1000)));

        SimpleVesting simpleVesting = new SimpleVesting(beneficiary, unlockTime);
        deployedAddress = address(simpleVesting);

        vm.stopBroadcast();
    }
}

// forge script script/DeploySimpleVesting.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ARBISCAN_API_KEY --optimize --optimizer-runs 1000
