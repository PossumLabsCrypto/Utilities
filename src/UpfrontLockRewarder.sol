// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

///@notice This contract allows users to lock a staking token to receive upfront rewards in a reward token
contract UpfrontLockRewarder {
    constructor(address _stakeToken, address _rewardToken, uint256 _maxLockDuration, uint256 _rewardPerTokenSecond) {
        ///@dev Validity check of the tokens
        if (_stakeToken == address(0) || _rewardToken == address(0)) revert InvalidConstructor();
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);

        ///@dev Ensure maximum duration between 1 week and 5 years (safeguard)
        if (_maxLockDuration < 604800 || _maxLockDuration > 157680000) revert InvalidConstructor();
        maxLockDuration = _maxLockDuration;

        ///@dev Sanity check of the reward per second & token staked
        if (_rewardPerTokenSecond == 0) revert InvalidConstructor();
        rewardPerTokenSecond = _rewardPerTokenSecond;
    }

    // ============================================
    // ==                STORAGE                 ==
    // ============================================
    using SafeERC20 for IERC20;

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;
    uint256 public immutable maxLockDuration;
    uint256 public immutable rewardPerTokenSecond;
    uint256 public constant precision = 1e18;

    uint256 public stakeCounter; // number of total stakes
    uint256 public totalStaked; // Combined amount of all active stakes

    mapping(uint256 stakeID => address owner) public stakeOwners;
    mapping(uint256 stakeID => uint256 stakeBalance) public stakeBalances;
    mapping(uint256 stakeID => uint256 unlockTime) public stakeUnlocks;

    // ============================================
    // ==                EVENTS                  ==
    // ============================================
    event StakeLocked(
        address indexed staker,
        address indexed recipient,
        uint256 lockedAmount,
        uint256 rewardAmount,
        uint256 unlockTime,
        uint256 stakeID
    );

    event Unstaked(address indexed owner, uint256 amount, uint256 stakeID);

    // ============================================
    // ==              FUNCTIONS                 ==
    // ============================================
    ///@notice Calculates the result of a new stake
    function getLockResult(uint256 _amount, uint256 _duration)
        public
        view
        returns (uint256 amountLocked, uint256 upfrontReward, uint256 unlockTime)
    {
        ///@dev Ensure the duration stays within maximum
        if (_duration > maxLockDuration) revert LockTimeTooLong();

        ///@dev Calculate the default reward expectation and contract balance
        uint256 reward = (_amount * _duration * rewardPerTokenSecond) / precision;
        uint256 rewardBalance = (address(rewardToken) == address(stakeToken))
            ? rewardToken.balanceOf(address(this)) - totalStaked
            : rewardToken.balanceOf(address(this));

        ///@dev Ensure that there are available rewards in the contract
        if (rewardBalance == 0) revert NoRewardAvailable();

        ///@dev Ensure that the expected reward is positive
        if (reward == 0) revert InvalidAmountOrDuration();

        ///@dev Calculate the reward and the actual locked tokens
        if (reward <= rewardBalance) {
            upfrontReward = reward;
            amountLocked = _amount;
        } else {
            upfrontReward = rewardBalance; // grant all remaining reward balance
            amountLocked = (_amount * rewardBalance) / reward; // lock just enough staking tokens to get rewards
        }

        ///@dev Calculate the unlock timestamp
        unlockTime = block.timestamp + _duration;
    }

    ///@notice Lock staking tokens to receive reward tokens immediately
    function lockStake(address _rewardRecipient, uint256 _amount, uint256 _duration) external {
        // CHECKS
        ///@dev Avoid sending rewards to the zero address
        if (_rewardRecipient == address(0)) revert InvalidAddress();

        // EFFECTS
        ///@dev Calculate the upfront reward & locked tokens
        (uint256 lockedAmount, uint256 reward, uint256 unlockTime) = getLockResult(_amount, _duration);

        ///@dev Create user stake
        uint256 stakeID = stakeCounter;
        stakeOwners[stakeID] = msg.sender;
        stakeBalances[stakeID] = lockedAmount;
        stakeUnlocks[stakeID] = unlockTime;

        ///@dev Increase global stakeCounter & totalStaked
        stakeCounter = stakeID + 1;
        totalStaked += lockedAmount;

        // INTERACTIONS
        ///@dev Take staking tokens from the user
        stakeToken.safeTransferFrom(msg.sender, address(this), lockedAmount);

        ///@dev Send the upfront reward to the recipient
        rewardToken.safeTransfer(_rewardRecipient, reward);

        ///@dev Emit the staking event
        emit StakeLocked(msg.sender, _rewardRecipient, lockedAmount, reward, unlockTime, stakeID);
    }

    ///@notice Withdraw the balance of a stake ID after the lock expired
    function withdrawStake(uint256 _stakeID) external {
        // CHECKS
        ///@dev Cache params
        address owner = stakeOwners[_stakeID];
        uint256 balance = stakeBalances[_stakeID];
        uint256 unlockTime = stakeUnlocks[_stakeID];

        ///@dev Check if the caller is the owner of the stake
        if (msg.sender != owner) revert NotOwnerOfStake();

        ///@dev Ensure the lock duration has expired
        if (block.timestamp < unlockTime) revert StakeLockNotExpired();

        // EFFECTS
        ///@dev Delete the stake from storage
        delete stakeOwners[_stakeID];
        delete stakeBalances[_stakeID];
        delete stakeUnlocks[_stakeID];

        ///@dev Update global stake tracker
        totalStaked -= balance;

        // INTERACTIONS
        ///@dev Send stake to the recipient
        stakeToken.safeTransfer(owner, balance);

        ///@dev Emit the unstake event
        emit Unstaked(owner, balance, _stakeID);
    }
}
