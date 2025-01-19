// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

///@notice This contract allows users to stake a token to receive rewards in a different token
///@dev The deployer becomes the sponsor of the contract
///@dev Only the sponsor can add additional rewards over time
///@dev The sponsor must send the reward tokens to the contract after deployment
contract StakingRewarder {
    constructor(address _stakingToken, uint256 _totalReward, uint256 _distributionDuration) {
        require(_stakingToken != address(0), "Invalid staking token address");
        require(_totalReward > 0, "Total reward must be greater than zero");
        require(_distributionDuration > 0, "Distribution duration must be greater than zero");

        sponsor = msg.sender;
        stakingToken = IERC20(_stakingToken);
        totalReward = _totalReward;
        distributionDeadline = block.timestamp + _distributionDuration;
        rewardRatePerSecond = _totalReward / _distributionDuration;
    }

    // ============================================
    // ==            GLOBAL VARIABLES            ==
    // ============================================
    using SafeERC20 for IERC20;

    // Constants
    IERC20 public immutable stakingToken;
    IERC20 public constant rewardToken = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5); // Replace with actual reward token address
    address public immutable sponsor;

    // Reward distribution
    uint256 public totalReward;
    uint256 public distributionDeadline;
    uint256 public rewardRatePerSecond;

    // User balances and rewards
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    // ============================================
    // ==                EVENTS                  ==
    // ============================================
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardsAdded(uint256 amount, uint256 newDistributionDeadline);

    // ============================================
    // ==               MODIFIERS                ==
    // ============================================
    ///@notice Updates the reward for a specific account
    ///@param account The account to update rewards for
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;

        _;
    }

    // ============================================
    // ==              FUNCTIONS                 ==
    // ============================================
    ///@notice Returns the last time rewards are applicable
    ///@return The last time rewards are applicable, either the current time or the distribution deadline
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < distributionDeadline ? block.timestamp : distributionDeadline;
    }

    ///@notice Calculates the current reward per token staked
    ///@return The reward per token in 18 decimal places
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRatePerSecond * 1e18) / totalStaked;
    }

    ///@notice Calculates the earned (pending) rewards for a specific account
    ///@param account The address of the account
    ///@return The amount of rewards earned
    function earned(address account) public view returns (uint256) {
        return
            (stakedBalances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    ///@notice Stakes tokens in the contract
    ///@param amount The amount of tokens to stake
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake zero tokens");
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    ///@notice Withdraws staked tokens from the contract and claims rewards
    ///@param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) external {
        require(amount > 0, "Cannot withdraw zero tokens");
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");

        ///@dev Claim & withdraw the rewards to the user
        _claimReward(msg.sender);

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    ///@notice Claims reward tokens for the caller
    function claimReward() public {
        _claimReward(msg.sender);
    }

    ///@notice Internal function to claim reward tokens for a user
    function _claimReward(address _user) private updateReward(_user) {
        uint256 reward = rewards[_user];
        if (rewards[_user] > 0) {
            rewards[_user] = 0;
            rewardToken.safeTransfer(_user, reward);
            emit RewardClaimed(_user, reward);
        }
    }

    ///@notice Allows the owner to add additional rewards and extend the distribution deadline.
    ///@param _additionalReward The amount of additional reward tokens to add.
    ///@param _additionalDuration The additional duration to extend the distribution deadline by (in seconds).
    function addRewards(uint256 _additionalReward, uint256 _additionalDuration) external updateReward(msg.sender) {
        require(block.timestamp < distributionDeadline, "Deadline has passed, make new contract");
        require(_additionalReward > 0, "Additional reward must be greater than zero");
        require(msg.sender == sponsor, "Not authorized");

        // Update the reward and deadline
        totalReward += _additionalReward;
        distributionDeadline += _additionalDuration;

        // Recalculate the reward rate per second
        uint256 remainingDuration = distributionDeadline - block.timestamp;
        uint256 newRewardRate = totalReward / remainingDuration;

        ///@dev Ensure that the reward rate cannot decrease
        require(newRewardRate >= rewardRatePerSecond, "Reward rate cannot decrease");
        rewardRatePerSecond = newRewardRate;

        ///@dev Transfer the reward token to the contract
        rewardToken.safeTransferFrom(msg.sender, address(this), _additionalReward);

        emit RewardsAdded(_additionalReward, distributionDeadline);
    }
}
