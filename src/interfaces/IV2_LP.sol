// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IV2_LP {
    function getProfitOfPortal(address _portal) external view returns (uint256 profitOfPortal);
    function collectProfitOfPortal(address _portal) external;
    function convert(address _token, address _recipient, uint256 _minReceived, uint256 _deadline) external;
}
