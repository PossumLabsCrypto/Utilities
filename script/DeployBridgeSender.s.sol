// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {BridgeSender} from "src/BridgeSender.sol";

contract DeployBridgeSender is Script {
    function setUp() public {}

    address L1_token = 0x1330918030fB1032e1245FE2E2F499f02B916e19;
    address L2_token = 0xDf539Ae47B7F09F58Ea5f9d0b44ACcDd312B9330;
    address L2_recipient = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    function run() public returns (address deployedAddress) {
        vm.startBroadcast();

        // Configure optimizer settings
        vm.store(address(this), bytes32("optimizer"), bytes32("true"));
        vm.store(address(this), bytes32("optimizerRuns"), bytes32(uint256(100)));

        BridgeSender bridgeSender = new BridgeSender(L1_token, L2_token, L2_recipient);
        deployedAddress = address(bridgeSender);

        vm.stopBroadcast();
    }
}

// forge script script/BridgeSender.s.sol --rpc-url $ETH_MAINNET_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY --optimize --optimizer-runs 100
