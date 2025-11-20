// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LinearVesting} from "src/LinearVesting.sol";

contract DeployLinearVesting is Script {
    function setUp() public {}

    address beneficiary = 0xE24d295154c2D78A7A860E809D57598E551813Bd;
    address vestingToken = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    uint256 unlockPerSecond = 1_929_012_345_679_010_000; // 5M tokens per month
    uint256 startTime = 1763658000; // Nov 22, 17:00 UTC

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        LinearVesting linearVesting = new LinearVesting(beneficiary, vestingToken, unlockPerSecond, startTime);
        deployedAddress = address(linearVesting);

        vm.stopBroadcast();
    }
}

// forge script script/DeployLinearVesting.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY --optimize --optimizer-runs 1000
