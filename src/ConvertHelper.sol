// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface portal {
    function convert(
        address _token,
        uint256 _minReceived,
        uint256 _deadline
    ) external;

    function getPendingRewards(
        address _rewarder
    ) external view returns (uint256 claimableReward);

    function claimRewardsHLPandHMX() external;

    function claimRewardsManual(
        address[] memory _pools,
        address[][] memory _rewarders
    ) external;
}

error InsufficientBalance();
error InvalidInput();
error InsufficientReward();

/// @title ConvertHelper for the HLP Portal on Arbitrum
/// @author Possum Labs
/// @notice This contract claims pending rewards and executes the convert() function of the HLP Portal in a single transaction.
contract ConvertHelper is ReentrancyGuard {
    constructor() {}

    // Variables
    using SafeERC20 for IERC20;

    address payable public constant HLP_PORTAL_ADDRESS =
        payable(0x24b7d3034C711497c81ed5f70BEE2280907Ea1Fa);
    portal constant HLP_PORTAL = portal(HLP_PORTAL_ADDRESS);

    address payable public constant HLP_STAKING =
        payable(0xbE8f8AF5953869222eA8D39F1Be9d03766010B1C);
    address public constant HLP_PROTOCOL_REWARDER =
        0x665099B3e59367f02E5f9e039C3450E31c338788;
    address public constant HMX_PROTOCOL_REWARDER =
        0xB698829C4C187C85859AD2085B24f308fC1195D3;
    address public constant HLP_STIP_REWARDER_ARB =
        0x238DAF7b15342113B00fA9e3F3E60a11Ab4274fD;

    address public constant PSM = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    uint256 public constant PSM_AMOUNT_FOR_CONVERT = 100000 * 1e18;

    address public constant USDCE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    // Functions
    function convertUSDC(uint256 _minReceived) public {
        if (_minReceived == 0) {
            revert InvalidInput();
        }
        uint256 reward = getCurrentRewardsUSDC();
        if (reward < _minReceived) {
            revert InsufficientReward();
        }

        IERC20(PSM).safeIncreaseAllowance(
            HLP_PORTAL_ADDRESS,
            PSM_AMOUNT_FOR_CONVERT
        );
        IERC20(PSM).transferFrom(
            msg.sender,
            address(this),
            PSM_AMOUNT_FOR_CONVERT
        );

        HLP_PORTAL.claimRewardsHLPandHMX();
        HLP_PORTAL.convert(USDCE, reward, block.timestamp);

        IERC20(USDCE).transfer(msg.sender, reward);
    }

    function convertARB(uint256 _minReceived) public {
        if (_minReceived == 0) {
            revert InvalidInput();
        }
        uint256 reward = getCurrentRewardsARB();
        if (reward < _minReceived) {
            revert InsufficientReward();
        }

        IERC20(PSM).safeIncreaseAllowance(
            HLP_PORTAL_ADDRESS,
            PSM_AMOUNT_FOR_CONVERT
        );
        IERC20(PSM).transferFrom(
            msg.sender,
            address(this),
            PSM_AMOUNT_FOR_CONVERT
        );

        address[] memory pools = new address[](1);
        pools[0] = HLP_STAKING;

        address[][] memory rewarders = new address[][](1);
        rewarders[0] = new address[](1);
        rewarders[0][0] = HLP_STIP_REWARDER_ARB;

        HLP_PORTAL.claimRewardsManual(pools, rewarders);
        HLP_PORTAL.convert(ARB, reward, block.timestamp);

        IERC20(ARB).transfer(msg.sender, reward);
    }

    function getCurrentRewardsUSDC()
        public
        view
        returns (uint256 availableReward)
    {
        uint256 USDCrewards = HLP_PORTAL.getPendingRewards(
            HLP_PROTOCOL_REWARDER
        ) + HLP_PORTAL.getPendingRewards(HMX_PROTOCOL_REWARDER);
        availableReward =
            IERC20(USDCE).balanceOf(address(this)) +
            IERC20(USDCE).balanceOf(address(HLP_PORTAL_ADDRESS)) +
            USDCrewards;
    }

    function getCurrentRewardsARB()
        public
        view
        returns (uint256 availableReward)
    {
        uint256 ARBrewards = HLP_PORTAL.getPendingRewards(
            HLP_STIP_REWARDER_ARB
        );
        availableReward =
            IERC20(ARB).balanceOf(address(this)) +
            IERC20(ARB).balanceOf(address(HLP_PORTAL_ADDRESS)) +
            ARBrewards;
    }

    // Send stuck tokens to the Portal with a 10% caller reward
    function extractToken(
        address _token,
        uint256 _minReward
    ) public nonReentrant {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        uint256 reward = balance / 10;
        if (_minReward == 0) {
            revert InvalidInput();
        }
        if (reward < _minReward) {
            revert InsufficientReward();
        }

        balance -= reward;

        IERC20(_token).safeTransfer(msg.sender, reward);
        IERC20(_token).safeTransfer(HLP_PORTAL_ADDRESS, balance);
    }
}
