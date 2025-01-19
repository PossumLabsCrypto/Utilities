// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "../src/StakingRewarder.sol";
import "./Mocks/ERC20Mock.sol";

contract StakingContractTest is Test {
    ERC20Mock stakingToken;
    IERC20 rewardToken = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    StakingRewarder stakingRewarder;
    address owner;
    address user1;
    address user2;
    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;
    uint256 initialReward = 1000 ether;
    uint256 duration = 86400;
    uint256 startTime;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardsAdded(uint256 amount, uint256 newDistributionDeadline);

    function setUp() public {
        // Create main net fork
        vm.createSelectFork({urlOrAlias: "alchemy_arbitrum_api", blockNumber: 260000000});

        // Create addresses
        owner = address(this);
        user1 = address(76563);
        user2 = address(30938);

        // Deploy mock ERC20 tokens for staking and rewards
        stakingToken = new ERC20Mock("Staking Token", "STK");
        startTime = block.timestamp;

        // Mint tokens to owner
        stakingToken.mint(owner, 1_000_000 ether);

        // Deploy the staking contract
        stakingRewarder = new StakingRewarder(
            address(stakingToken),
            initialReward, // Total reward
            duration // Distribution duration (1 day)
        );

        // Transfer reward tokens to the contract
        vm.startPrank(psmSender);
        rewardToken.transfer(address(stakingRewarder), initialReward);
        rewardToken.transfer(owner, initialReward);
        vm.stopPrank();
    }

    function testConstructor() public {
        // Deploy a new staking contract with bad inputs
        vm.expectRevert("Invalid staking token address");
        stakingRewarder = new StakingRewarder(
            address(0),
            initialReward, // Total reward
            duration // Distribution duration (1 day)
        );

        // Deploy a new staking contract with bad inputs
        vm.expectRevert("Total reward must be greater than zero");
        stakingRewarder = new StakingRewarder(
            address(this),
            0, // Total reward
            duration // Distribution duration (1 day)
        );

        // Deploy a new staking contract with bad inputs
        vm.expectRevert("Distribution duration must be greater than zero");
        stakingRewarder = new StakingRewarder(
            address(this),
            initialReward, // Total reward
            0 // Distribution duration (1 day)
        );
    }

    function testStake() public {
        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Staked(user1, 60 ether);
        stakingRewarder.stake(60 ether);
        vm.stopPrank();

        assertEq(stakingRewarder.stakedBalances(user1), 60 ether);
        assertEq(stakingToken.balanceOf(user1), 40 ether);
    }

    function testStakeZeroTokens() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewarder), 1e55);

        vm.expectRevert("Cannot stake zero tokens");
        stakingRewarder.stake(0);
        vm.stopPrank();
    }

    function testWithdraw() public {
        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        vm.prank(user1);
        stakingRewarder.stake(50 ether);

        vm.prank(user1);
        stakingRewarder.withdraw(50 ether);

        assertEq(stakingRewarder.stakedBalances(user1), 0);
        assertEq(stakingToken.balanceOf(user1), 100 ether);
    }

    function testWithdrawZeroTokens() public {
        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        vm.prank(user1);
        stakingRewarder.stake(50 ether);

        vm.prank(user1);
        vm.expectRevert("Cannot withdraw zero tokens");
        stakingRewarder.withdraw(0);
    }

    function testWithdrawMoreThanStaked() public {
        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        vm.prank(user1);
        stakingRewarder.stake(50 ether);

        vm.prank(user1);
        vm.expectRevert("Insufficient staked balance");
        stakingRewarder.withdraw(60 ether);
    }

    function testClaimReward() public {
        // User without stake
        vm.prank(user1);
        stakingRewarder.claimReward();

        uint256 reward = stakingRewarder.rewards(user1);
        assertEq(reward, 0);

        // User with stake
        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        vm.prank(user1);
        stakingRewarder.stake(50 ether);

        vm.warp(block.timestamp + 43200); // Advance time by 12 hours

        uint256 earned = stakingRewarder.earned(user1);

        vm.prank(user1);
        stakingRewarder.claimReward();

        assertEq(rewardToken.balanceOf(user1), earned);
    }

    function testAddRewards() public {
        rewardToken.approve(address(stakingRewarder), 501 ether);

        stakingRewarder.addRewards(501 ether, 43200);

        assertEq(stakingRewarder.totalReward(), 1_501 ether);
        assertTrue(stakingRewarder.distributionDeadline() > block.timestamp);
    }

    function testAddRewardsZeroTime() public {
        rewardToken.approve(address(stakingRewarder), 500 ether);

        stakingRewarder.addRewards(500 ether, 0);

        assertEq(stakingRewarder.totalReward(), 1_500 ether);
        assertTrue(stakingRewarder.distributionDeadline() > block.timestamp);
    }

    function testAddRewardsUnauthorized() public {
        stakingToken.transfer(user1, 500 ether);

        vm.startPrank(user1);
        rewardToken.approve(address(stakingRewarder), 500 ether);
        vm.expectRevert("Not authorized");
        stakingRewarder.addRewards(500 ether, 43200);
    }

    function testAddRewardsLate() public {
        rewardToken.approve(address(stakingRewarder), 500 ether);

        vm.warp(block.timestamp + 432000); // Advance time by 120 hours

        vm.expectRevert("Deadline has passed, make new contract");
        stakingRewarder.addRewards(500 ether, 43200);
    }

    function testAddRewardsZeroAmount() public {
        rewardToken.approve(address(stakingRewarder), 500 ether);

        vm.expectRevert("Additional reward must be greater than zero");
        stakingRewarder.addRewards(0, 43200);
    }

    function testAddRewardsDecreaseRatio() public {
        rewardToken.approve(address(stakingRewarder), 500 ether);

        vm.expectRevert("Reward rate cannot decrease");
        stakingRewarder.addRewards(1, 43200);
    }

    function testViewFunctions() public {
        uint256 stakingAmount = 50 ether;

        stakingToken.transfer(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewarder), 100 ether);

        uint256 rewardPerToken = stakingRewarder.rewardPerToken();
        assertEq(rewardPerToken, 0);

        uint256 lastUpdateTime = stakingRewarder.lastUpdateTime();
        assertEq(lastUpdateTime, 0);

        uint256 lastRewardTime = stakingRewarder.lastTimeRewardApplicable();
        assertEq(lastRewardTime, block.timestamp);

        vm.prank(user1);
        stakingRewarder.stake(stakingAmount);

        lastUpdateTime = stakingRewarder.lastUpdateTime();
        assertEq(lastUpdateTime, block.timestamp);

        vm.warp(block.timestamp + 43200); // Advance time by 12 hours

        lastRewardTime = stakingRewarder.lastTimeRewardApplicable();
        assertEq(lastRewardTime, block.timestamp);

        rewardPerToken = stakingRewarder.rewardPerToken();
        uint256 rewardStored = stakingRewarder.rewardPerTokenStored();
        uint256 rewardPerSecond = stakingRewarder.rewardRatePerSecond();
        uint256 calculatedRewardPerToken = rewardStored + (43200 * 1e18 * rewardPerSecond) / stakingAmount;

        assertEq(rewardPerToken, calculatedRewardPerToken);

        vm.warp(block.timestamp + 432000); // Advance time by 120 hours

        lastRewardTime = stakingRewarder.lastTimeRewardApplicable();
        assertEq(lastRewardTime, startTime + duration);
    }
}
