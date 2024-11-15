// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IWETH_ARB {
    function deposit() external payable;
    function withdrawTo(address payable _account, uint256 _amount) external;
}
