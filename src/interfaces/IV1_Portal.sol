// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IV1_Portal {
    function getPendingRewards(address _rewarder) external view returns (uint256 claimableReward);
    function claimRewardsHLPandHMX() external;
    function convert(address _token, uint256 _minReceived, uint256 _deadline) external;
    function maxLockDuration() external view returns (uint256 maxLockDuration);
    function updateMaxLockDuration() external;
}
