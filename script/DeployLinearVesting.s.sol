// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LinearVesting} from "src/LinearVesting.sol";

contract DeployLinearVesting is Script {
    function setUp() public {}

    address owner = 0xbFF0b8CcD7ebA169107bbE72426dB370407C8f2D;
    address vestingToken = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    uint256 unlockPerMonth = 5_000_000e18;
    uint256 startTime = 1769871600; // Jan 31, 15:00 UTC

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        LinearVesting linearVesting = new LinearVesting(owner, vestingToken, unlockPerMonth, startTime);
        deployedAddress = address(linearVesting);

        vm.stopBroadcast();
    }
}

// forge script script/DeployLinearVesting.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY --optimize --optimizer-runs 1000
