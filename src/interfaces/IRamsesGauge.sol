// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IRamsesGauge {
    function notifyRewardAmount(address token, uint256 reward) external;
}
