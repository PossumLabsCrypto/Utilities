// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IConvertHelper {
    function V1_getRewardsUSDCE() external view returns (uint256 availableReward);
    function V2_getRewards(address _portal) external view returns (uint256 availableReward);

    function V1_convertUSDCE(address _recipient, uint256 _minReceived) external;
    function V2_convert(address _portal, address _recipient, uint256 _minReceived) external;
}
