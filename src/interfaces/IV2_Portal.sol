// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IV2_Portal {
    function PRINCIPAL_TOKEN_ADDRESS() external view returns (address PRINCIPAL_TOKEN_ADDRESS);
    function maxLockDuration() external view returns (uint256 maxLockDuration);
    function updateMaxLockDuration() external;
}
