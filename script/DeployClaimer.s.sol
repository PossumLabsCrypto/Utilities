// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {Claimer} from "src/Claimer.sol";

contract DeployClaimer is Script {
    function setUp() public {}

    address beneficiary = 0x7ff416268a59025fAf8D6857AC87a3389dB1fb93;
    uint256 claimInterval = 1209600;
    uint256 firstClaimTime = 1732428000;

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        Claimer claimer = new Claimer(beneficiary, claimInterval, firstClaimTime);
        deployedAddress = address(claimer);

        vm.stopBroadcast();
    }
}

// forge script script/DeployClaimer.s.sol --rpc-url $ARB_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ARBISCAN_API_KEY --optimize --optimizer-runs 1000
