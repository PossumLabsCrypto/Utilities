// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpfrontLockRewarder} from "../src/UpfrontLockRewarder.sol";

// ============================================
error NoRewardAvailable();
error InvalidAddress();
error InvalidAmountOrDuration();
error InvalidConstructor();
error InvalidStakeID();
error LockTimeTooLong();
error NotOwnerOfStake();
error StakeLockNotExpired();
// ============================================

contract CounterTest is Test {
    // addresses
    address payable Alice = payable(address(0x117));
    address payable Bob = payable(address(0x118));
    address payable treasury = payable(0xa0BFD02a7a47CBCA7230E03fbf04A196C3E771E3);
    IERC20 psm = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    IERC20 usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    // token amounts
    uint256 treasuryBalance;
    uint256 testUserBalance = 1e25; // 10M tokens
    uint256 contractLoad = 3e24; // 3M tokens

    // Contracts
    UpfrontLockRewarder rewarder;

    // time
    uint256 oneYear = 60 * 60 * 24 * 365;
    uint256 oneWeek = 60 * 60 * 24 * 7;

    // Constructor data
    address stakeToken = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    address rewardToken = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    uint256 maxLock = 63072000; // -> 2 years of 365 days
    uint256 rewardPerTokenSecond = 9512937595; // scaled by PRECISION -> 30% APR
    uint256 precision = 1e18;

    function setUp() public {
        // Create main net fork
        vm.createSelectFork({urlOrAlias: "alchemy_arbitrum_api", blockNumber: 339289690});

        // Create contract instances
        rewarder = new UpfrontLockRewarder(stakeToken, rewardToken, maxLock, rewardPerTokenSecond);

        // Calculate & distribute token balances
        vm.startPrank(treasury);
        psm.transfer(Alice, testUserBalance); // 10M PSM to Alice
        psm.transfer(Bob, testUserBalance); // 10M PSM to Bob
        psm.transfer(address(rewarder), contractLoad); // 100M PSM to rewarder
        vm.stopPrank();

        treasuryBalance = psm.balanceOf(treasury);
    }

    // ============================================
    // ==                 TESTS                  ==
    // ============================================
    // Verify deployment
    function testSuccess_deploy() public {
        UpfrontLockRewarder newRewarder =
            new UpfrontLockRewarder(stakeToken, rewardToken, maxLock, rewardPerTokenSecond);

        assertEq(address(newRewarder.stakeToken()), stakeToken);
        assertEq(address(newRewarder.rewardToken()), rewardToken);

        assertEq(newRewarder.maxLockDuration(), maxLock);
        assertEq(newRewarder.rewardPerTokenSecond(), rewardPerTokenSecond);

        assertEq(newRewarder.stakeCounter(), 0);
        assertEq(newRewarder.totalStaked(), 0);
    }

    function testRevert_deploy() public {
        UpfrontLockRewarder newRewarder1;
        UpfrontLockRewarder newRewarder2;
        UpfrontLockRewarder newRewarder3;
        UpfrontLockRewarder newRewarder4;
        UpfrontLockRewarder newRewarder5;

        vm.expectRevert(InvalidConstructor.selector);
        newRewarder1 = new UpfrontLockRewarder(address(0), rewardToken, maxLock, rewardPerTokenSecond);

        vm.expectRevert(InvalidConstructor.selector);
        newRewarder2 = new UpfrontLockRewarder(stakeToken, address(0), maxLock, rewardPerTokenSecond);

        vm.expectRevert(InvalidConstructor.selector);
        newRewarder3 = new UpfrontLockRewarder(stakeToken, rewardToken, 1, rewardPerTokenSecond);

        vm.expectRevert(InvalidConstructor.selector);
        newRewarder4 = new UpfrontLockRewarder(stakeToken, rewardToken, 111111111111111111111, rewardPerTokenSecond);

        vm.expectRevert(InvalidConstructor.selector);
        newRewarder5 = new UpfrontLockRewarder(stakeToken, rewardToken, maxLock, 0);
    }

    // Test staking
    function testSuccess_lockStake() public {
        // simple stake
        uint256 amount = 1e24; // 1 million

        vm.startPrank(Alice);
        psm.approve(address(rewarder), 1e55);
        rewarder.lockStake(Bob, amount, maxLock);
        vm.stopPrank();

        // expected reward
        uint256 expectedReward = (1e24 * maxLock * rewardPerTokenSecond) / precision;

        assertEq(psm.balanceOf(Alice), 9e24);
        assertEq(psm.balanceOf(Bob), 1e25 + expectedReward);
        assertEq(psm.balanceOf(address(rewarder)), contractLoad + amount - expectedReward);
        assertEq(rewarder.totalStaked(), amount);

        // stake that takes the rest but not need the full stake amount
        uint256 leftover = psm.balanceOf(address(rewarder)) - rewarder.totalStaked();
        uint256 requiredStake = (leftover * precision) / (rewardPerTokenSecond * maxLock);

        (uint256 requiredCalcByContract, uint256 reward, uint256 timestamp) =
            rewarder.getLockResult(8 * amount, maxLock);

        assertEq(requiredStake, requiredCalcByContract);
        assertEq(reward, leftover);
        assertEq(timestamp, block.timestamp + maxLock);

        vm.prank(Alice);
        rewarder.lockStake(Bob, 8 * amount, maxLock); // Try stake 8M but only rewards left for 6M

        assertEq(psm.balanceOf(Alice), 9e24 - requiredStake);
        assertEq(psm.balanceOf(Bob), 1e25 + contractLoad);
    }

    // Revert cases
    function testRevert_lockStake() public {
        vm.startPrank(Alice);
        psm.approve(address(rewarder), 1e55);

        // Scenario 1: zero address as recipient
        vm.expectRevert(InvalidAddress.selector);
        rewarder.lockStake(address(0), 1e24, maxLock);

        // Scenario 2: Too long duration
        vm.expectRevert(LockTimeTooLong.selector);
        rewarder.lockStake(Bob, 1e24, maxLock + 1);

        // Scenario 3: 0 stake amount
        vm.expectRevert(InvalidAmountOrDuration.selector);
        rewarder.lockStake(Bob, 0, maxLock);

        // Scenario 4: 0 duration
        vm.expectRevert(InvalidAmountOrDuration.selector);
        rewarder.lockStake(Bob, 1e24, 0);

        // Scenario 5: No reward balance left
        rewarder.lockStake(Bob, 1e25, maxLock);
        assertEq(rewarder.totalStaked(), psm.balanceOf(address(rewarder))); // Check that the contract has tokens but they are staked

        vm.expectRevert(NoRewardAvailable.selector);
        rewarder.lockStake(Bob, 1e24, maxLock);

        vm.stopPrank();
    }

    // Test withdrawing
    function testSuccess_withdrawStake() public {
        uint256 amount = 1e24; // 1 million

        vm.startPrank(Alice);
        psm.approve(address(rewarder), 1e55);
        rewarder.lockStake(Bob, amount, maxLock);

        uint256 time = block.timestamp;

        assertEq(rewarder.stakeOwners(0), Alice);
        assertEq(rewarder.totalStaked(), amount);
        assertEq(rewarder.stakeBalances(0), amount);
        assertEq(rewarder.stakeUnlocks(0), time + maxLock);
        assertEq(psm.balanceOf(Alice), 9e24);

        vm.warp(time + maxLock);
        rewarder.withdrawStake(0);

        assertEq(rewarder.stakeOwners(0), address(0));
        assertEq(rewarder.totalStaked(), 0);
        assertEq(rewarder.stakeBalances(0), 0);
        assertEq(rewarder.stakeUnlocks(0), 0);
        assertEq(psm.balanceOf(Alice), 1e25);

        vm.stopPrank();
    }

    // Revert cases
    function testRevert_withdrawStake() public {
        uint256 amount = 1e24; // 1 million

        (, uint256 expectedReward,) = rewarder.getLockResult(amount, maxLock);

        vm.startPrank(Alice);
        psm.approve(address(rewarder), 1e55);
        rewarder.lockStake(Bob, amount, maxLock);

        uint256 time = block.timestamp;

        assertEq(rewarder.stakeOwners(0), Alice);
        assertEq(rewarder.totalStaked(), amount);
        assertEq(rewarder.stakeBalances(0), amount);
        assertEq(rewarder.stakeUnlocks(0), time + maxLock);
        assertEq(psm.balanceOf(Alice), 9e24);
        assertEq(psm.balanceOf(address(rewarder)), contractLoad + amount - expectedReward);

        // Scenario 1: Stake didn't mature yet
        vm.expectRevert(StakeLockNotExpired.selector);
        rewarder.withdrawStake(0);

        vm.stopPrank();

        // Scenario 2: Not owner of stake
        vm.prank(Bob);
        vm.expectRevert(NotOwnerOfStake.selector);
        rewarder.withdrawStake(0);
    }
}
