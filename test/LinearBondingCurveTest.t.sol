// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {LinearBondingCurve} from "../src/LinearBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ============================================
error NotOwner();
error NullAddress();
error ZeroBalance();
error InvalidAmount();
error InvalidToken();
error InsufficientReceived();
error DeadlineExpired();
error ViolatedInvariant();
error FailedToSendNativeToken();
error ZeroFees();
// ============================================

contract StakingContractTest is Test {
    IERC20 PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5); // PSM

    LinearBondingCurve bondingCurve;

    uint256 constant MIN_START_TIME = 1701363600;

    address owner = 0xa0BFD02a7a47CBCA7230E03fbf04A196C3E771E3;
    address user1;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    function setUp() public {
        // Create main net fork
        vm.createSelectFork({urlOrAlias: "alchemy_arbitrum_api", blockNumber: 260000000});

        // Create addresses
        user1 = address(30938);

        // Deploy the staking contract
        bondingCurve = new LinearBondingCurve(owner);
    }

    function testRevert_deployment() public {}

    function testSuccess_deployment() public {}
}
