// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LinearVesting} from "src/LinearVesting.sol";

contract DeployLinearVesting is Script {
    function setUp() public {}

    address beneficiary = 0xAC23698691311E2cD7A3993806745c06Ccb58384;
    address vestingToken = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    uint256 unlockPerSecond = 1762838999;

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        // Configure optimizer settings
        vm.store(address(this), bytes32("optimizer"), bytes32("true"));
        vm.store(address(this), bytes32("optimizerRuns"), bytes32(uint256(1000)));

        LinearVesting linearVesting = new LinearVesting(beneficiary, vestingToken, unlockPerSecond);
        deployedAddress = address(linearVesting);

        vm.stopBroadcast();
    }
}

// forge script script/DeployLinearVesting.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ARBISCAN_API_KEY --optimize --optimizer-runs 1000
