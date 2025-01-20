// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import {LinearVesting} from "../src/LinearVesting.sol";
import "./Mocks/ERC20Mock.sol";

error NotBeneficiary();
error ZeroTransfer();
error ZeroUnlock();
error NullAddress();

contract StakingContractTest is Test {
    ERC20Mock otherToken;
    IERC20 vestingToken = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5); // PSM

    LinearVesting linearVesting;
    uint256 unlockPerSecond = 1e17;
    uint256 vestingAmount = 1e22;

    address beneficiary;
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
        beneficiary = address(76563);
        user1 = address(30938);

        // Deploy mock ERC20 tokens for staking and rewards
        otherToken = new ERC20Mock("Staking Token", "STK");

        // Deploy the staking contract
        linearVesting = new LinearVesting(beneficiary, address(vestingToken), unlockPerSecond);

        // Mint tokens to the vesting contract (claimable donation)
        otherToken.mint(address(linearVesting), 1_000_000 ether);

        // Transfer vesting tokens to the contract
        vm.prank(psmSender);
        vestingToken.transfer(address(linearVesting), vestingAmount);
    }

    function testRevert_deployment() public {
        vm.expectRevert(NullAddress.selector);
        linearVesting = new LinearVesting(address(0), address(vestingToken), unlockPerSecond);

        vm.expectRevert(NullAddress.selector);
        linearVesting = new LinearVesting(beneficiary, address(0), unlockPerSecond);

        vm.expectRevert(ZeroUnlock.selector);
        linearVesting = new LinearVesting(beneficiary, address(vestingToken), 0);
    }

    function testSuccess_deployment() public {
        assertTrue(linearVesting.beneficiary() == beneficiary);
        assertTrue(linearVesting.vestingToken() == vestingToken);
        assertTrue(linearVesting.unlockPerSecond() == unlockPerSecond);
        assertTrue(linearVesting.start() == block.timestamp);
        assertTrue(linearVesting.claimed() == 0);
    }

    function testSuccess_changeBeneficiary() public {
        vm.prank(beneficiary);
        linearVesting.changeBeneficiary(user1);

        assertTrue(linearVesting.beneficiary() == user1);
    }

    function testRevert_changeBeneficiary() public {
        vm.expectRevert(NotBeneficiary.selector);
        linearVesting.changeBeneficiary(user1);

        vm.prank(beneficiary);
        vm.expectRevert(NullAddress.selector);
        linearVesting.changeBeneficiary(address(0));
    }

    function testSuccess_claim() public {
        // claim the spam token
        vm.prank(beneficiary);
        linearVesting.claim(address(otherToken));

        assertEq(otherToken.balanceOf(address(linearVesting)), 0);
        assertEq(otherToken.balanceOf(beneficiary), 1e24);

        // claim the vesting token
        uint256 secondsPassed = 100;
        vm.warp(block.timestamp + secondsPassed);

        vm.prank(beneficiary);
        linearVesting.claim(address(vestingToken));

        uint256 unlocked = secondsPassed * unlockPerSecond;

        assertEq(vestingToken.balanceOf(address(linearVesting)), vestingAmount - unlocked);
        assertEq(vestingToken.balanceOf(beneficiary), unlocked);
        assertEq(vestingToken.balanceOf(beneficiary), linearVesting.claimed());
    }

    function testRevert_claim() public {
        vm.expectRevert(NotBeneficiary.selector);
        linearVesting.claim(address(vestingToken));

        vm.startPrank(beneficiary);
        vm.expectRevert(ZeroTransfer.selector);
        linearVesting.claim(address(vestingToken));

        linearVesting.claim(address(otherToken));
        vm.expectRevert(ZeroTransfer.selector);
        linearVesting.claim(address(otherToken));

        vm.stopPrank();
    }

    function testSuccess_totalUnlocked() public {
        assertEq(0, linearVesting.totalUnlocked());

        uint256 secondsPassed = 100;
        vm.warp(block.timestamp + secondsPassed);

        uint256 unlocked = secondsPassed * unlockPerSecond;

        assertEq(unlocked, linearVesting.totalUnlocked());
    }
}
