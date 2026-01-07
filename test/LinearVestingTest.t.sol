// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import {LinearVesting} from "../src/LinearVesting.sol";
import "./Mocks/ERC20Mintable.sol";

error NotBeneficiary();
error ZeroTransfer();
error ZeroUnlock();
error NullAddress();
error InvalidTime();

contract StakingContractTest is Test {
    ERC20Mintable otherToken;
    IERC20 vestingToken = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5); // PSM

    LinearVesting linearVesting;
    uint256 unlockPerMonth = 1e17 * 60 * 60 * 24 * 30; // 0.1 token per second, = 259200 tokens per month
    uint256 unlockPerSecond = 1e17; // 0.1 token per second
    uint256 vestingAmount = 1e22;

    uint256 constant MIN_START_TIME = 1701363600;

    address owner;
    address user1;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardsAdded(uint256 amount, uint256 newDistributionDeadline);

    function setUp() public {
        // Create main net fork
        vm.createSelectFork({urlOrAlias: "alchemy_arbitrum_api", blockNumber: 260000000});

        // Create addresses
        owner = address(76563);
        user1 = address(30938);

        // Deploy mock ERC20 tokens for staking and rewards
        otherToken = new ERC20Mintable("Staking Token", "STK");

        // Deploy the staking contract
        linearVesting = new LinearVesting(owner, address(vestingToken), unlockPerMonth, block.timestamp);

        // Mint tokens to the vesting contract (claimable donation)
        otherToken.mint(address(linearVesting), 1_000_000 ether);

        // Transfer vesting tokens to the contract
        vm.prank(psmSender);
        vestingToken.transfer(address(linearVesting), vestingAmount);
    }

    function testRevert_deployment() public {
        vm.expectRevert(NullAddress.selector);
        linearVesting = new LinearVesting(address(0), address(vestingToken), unlockPerMonth, block.timestamp);

        vm.expectRevert(NullAddress.selector);
        linearVesting = new LinearVesting(owner, address(0), unlockPerMonth, block.timestamp);

        vm.expectRevert(ZeroUnlock.selector);
        linearVesting = new LinearVesting(owner, address(vestingToken), 0, block.timestamp);

        vm.expectRevert(InvalidTime.selector);
        linearVesting = new LinearVesting(owner, address(vestingToken), unlockPerMonth, MIN_START_TIME - 1);
    }

    function testSuccess_deployment() public {
        assertTrue(linearVesting.owner() == owner);
        assertTrue(linearVesting.vestingToken() == vestingToken);
        assertTrue(linearVesting.unlockPerMonth() == unlockPerMonth);
        assertTrue(linearVesting.start() == block.timestamp);
        assertTrue(linearVesting.claimed() == 0);
    }

    function testSuccess_changeBeneficiary() public {
        vm.prank(owner);
        linearVesting.changeBeneficiary(user1);

        assertTrue(linearVesting.owner() == user1);
    }

    function testRevert_changeBeneficiary() public {
        vm.expectRevert(NotBeneficiary.selector);
        linearVesting.changeBeneficiary(user1);

        vm.prank(owner);
        vm.expectRevert(NullAddress.selector);
        linearVesting.changeBeneficiary(address(0));
    }

    function testSuccess_claim() public {
        // claim the spam token
        vm.prank(owner);
        linearVesting.claim(address(otherToken));

        assertEq(otherToken.balanceOf(address(linearVesting)), 0);
        assertEq(otherToken.balanceOf(owner), 1e24);

        // claim the vesting token
        uint256 secondsPassed = 100;
        vm.warp(block.timestamp + secondsPassed);

        vm.prank(owner);
        linearVesting.claim(address(vestingToken));

        uint256 unlocked = secondsPassed * unlockPerSecond;

        assertEq(vestingToken.balanceOf(address(linearVesting)), vestingAmount - unlocked);
        assertEq(vestingToken.balanceOf(owner), unlocked);
        assertEq(vestingToken.balanceOf(owner), linearVesting.claimed());
    }

    function testRevert_claim() public {
        vm.expectRevert(NotBeneficiary.selector);
        linearVesting.claim(address(vestingToken));

        vm.startPrank(owner);
        vm.expectRevert(ZeroTransfer.selector);
        linearVesting.claim(address(vestingToken));

        linearVesting.claim(address(otherToken));
        vm.expectRevert(ZeroTransfer.selector);
        linearVesting.claim(address(otherToken));

        vm.stopPrank();
    }

    function testSuccess_pendingClaim() public {
        assertEq(0, linearVesting.pendingClaim());

        uint256 secondsPassed = 100;
        vm.warp(block.timestamp + secondsPassed);

        uint256 unlocked = secondsPassed * unlockPerSecond;

        assertEq(unlocked, linearVesting.pendingClaim());
    }
}
