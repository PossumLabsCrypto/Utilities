// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {RamsesIncentivizer} from "src/RamsesIncentivizer.sol";

contract DeployRamsesIncentivizer is Script {
    function setUp() public {}

    address gauge = 0x1614BBDe1C4c59280ebAFA25E410820f086EB4Ad;

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        // Configure optimizer settings
        vm.store(address(this), bytes32("optimizer"), bytes32("true"));
        vm.store(address(this), bytes32("optimizerRuns"), bytes32(uint256(1000)));

        RamsesIncentivizer ramsesIncentivizer = new RamsesIncentivizer(gauge);
        deployedAddress = address(ramsesIncentivizer);

        vm.stopBroadcast();
    }
}

// forge script script/DeployRamsesIncentivizer.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ARBISCAN_API_KEY --optimize --optimizer-runs 1000
