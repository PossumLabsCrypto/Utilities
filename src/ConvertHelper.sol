// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IV1_Portal} from "./interfaces/IV1_Portal.sol";
import {IV2_Portal} from "./interfaces/IV2_Portal.sol";
import {IV2_LP} from "./interfaces/IV2_LP.sol";

error InsufficientBalance();
error InvalidAddress();
error InvalidAmount();
error InsufficientReward();
error FailedToSendNativeToken();

/// @title ConvertHelper for PortalsV1 and V2 on Arbitrum
/// @author Possum Labs
/// @notice This contract claims pending rewards and executes the convert() function of the HLP Portal in a single transaction.
contract ConvertHelper {
    constructor() {}

    // Variables
    using SafeERC20 for IERC20;

    IERC20 public constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    uint256 public constant PSM_AMOUNT_FOR_CONVERT = 100000 * 1e18;

    IERC20 private constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    uint256 private constant MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Portal V1 related variables
    address payable private constant HLP_PORTAL_ADDRESS = payable(0x24b7d3034C711497c81ed5f70BEE2280907Ea1Fa);
    IV1_Portal public constant HLP_PORTAL = IV1_Portal(HLP_PORTAL_ADDRESS);
    address public constant HLP_PROTOCOL_REWARDER = 0x665099B3e59367f02E5f9e039C3450E31c338788;
    address public constant HMX_PROTOCOL_REWARDER = 0xB698829C4C187C85859AD2085B24f308fC1195D3;

    // Portal V2 related variables
    address payable private constant V2_VIRTUAL_LP_ADDRESS = payable(0x212Bbd56F6D4F999B2845adebd8cec147851E383);
    IV2_LP public constant V2_VIRTUAL_LP = IV2_LP(V2_VIRTUAL_LP_ADDRESS);

    ///////////////////////////////////////
    // Functions - Portals V1 Arbitrage
    ///////////////////////////////////////
    function V1_getRewardsUSDCE() public view returns (uint256 availableReward) {
        uint256 pendingRewards =
            HLP_PORTAL.getPendingRewards(HLP_PROTOCOL_REWARDER) + HLP_PORTAL.getPendingRewards(HMX_PROTOCOL_REWARDER);

        availableReward = pendingRewards + USDCE.balanceOf(address(this)) + USDCE.balanceOf(HLP_PORTAL_ADDRESS);
    }

    function V1_convertUSDCE(address _recipient, uint256 _minReceived) external {
        // Input Validation
        if (_minReceived == 0) revert InvalidAmount();
        if (_recipient == address(0)) revert InvalidAddress();

        // Check if enough rewards are available to trigger arbitrage
        uint256 reward = V1_getRewardsUSDCE();
        if (reward < _minReceived) revert InsufficientReward();

        // Attempt to update maxLockDuration of the Portal
        uint256 maxLockDuration = HLP_PORTAL.maxLockDuration();
        if (maxLockDuration < 157680000) HLP_PORTAL.updateMaxLockDuration();

        // Arbitrage sequence
        PSM.transferFrom(msg.sender, address(this), PSM_AMOUNT_FOR_CONVERT);
        HLP_PORTAL.claimRewardsHLPandHMX();
        HLP_PORTAL.convert(address(USDCE), 1, block.timestamp);

        // Transfer the rewards to the recipient
        USDCE.safeTransfer(_recipient, reward);
    }

    ///////////////////////////////////////
    // Functions - Portals V2 Arbitrage
    ///////////////////////////////////////
    function V2_getRewards(address _portal) public view returns (uint256 availableReward) {
        address principalTokenAddress = IV2_Portal(_portal).PRINCIPAL_TOKEN_ADDRESS();
        IERC20 principalToken = (principalTokenAddress == address(0)) ? WETH : IERC20(principalTokenAddress);

        uint256 pendingRewards = V2_VIRTUAL_LP.getProfitOfPortal(_portal);

        availableReward =
            pendingRewards + principalToken.balanceOf(address(this)) + principalToken.balanceOf(V2_VIRTUAL_LP_ADDRESS);
    }

    function V2_convert(address _portal, address _recipient, uint256 _minReceived) external {
        // Input Validation
        if (_minReceived == 0) revert InvalidAmount();
        if (_portal == address(0) || _recipient == address(0)) revert InvalidAddress();

        // Check if enough rewards are available to trigger arbitrage
        uint256 reward = V2_getRewards(_portal);
        if (reward < _minReceived) revert InsufficientReward();

        // Attempt to update maxLockDuration of the Portal
        uint256 maxLockDuration = IV2_Portal(_portal).maxLockDuration();
        if (maxLockDuration > 8640000 && maxLockDuration < 157680000) IV2_Portal(_portal).updateMaxLockDuration();

        // Arbitrage sequence
        address principalTokenAddress = IV2_Portal(_portal).PRINCIPAL_TOKEN_ADDRESS();
        IERC20 principalToken = (principalTokenAddress == address(0)) ? WETH : IERC20(principalTokenAddress);

        PSM.transferFrom(msg.sender, address(this), PSM_AMOUNT_FOR_CONVERT);

        V2_VIRTUAL_LP.collectProfitOfPortal(_portal);
        V2_VIRTUAL_LP.convert(address(principalToken), address(this), 1, block.timestamp);

        // Transfer the rewards to the recipient
        principalToken.safeTransfer(_recipient, reward);
    }

    ///////////////////////////////////////
    // General Functions
    ///////////////////////////////////////

    // Set spending allowance of PSM by Portals & V2 LP to execute convert()
    function increaseAllowances() external {
        PSM.approve(HLP_PORTAL_ADDRESS, MAX_UINT);
        PSM.approve(V2_VIRTUAL_LP_ADDRESS, MAX_UINT);
    }

    // Send stuck tokens to the HLP Portal with a 10% caller reward
    function extractToken(address _token, uint256 _minReward) external {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        uint256 reward = balance / 10;
        if (_minReward == 0) revert InvalidAmount();
        if (reward < _minReward) revert InsufficientReward();

        balance -= reward;

        IERC20(_token).safeTransfer(msg.sender, reward);
        IERC20(_token).safeTransfer(HLP_PORTAL_ADDRESS, balance);
    }
}
