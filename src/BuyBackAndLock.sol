// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH_ARB} from "src/interfaces/IWETH_ARB.sol";

error AmountTooLow();
error InsufficientWETH();
error InvalidAmount();
error NoSurplusWETH();
error NotAuthorized();

///@notice This contract repurchases the total supply of PSM with WETH at an increasing price
/* PSM is permanently locked in this contract, effectively removed from supply
*/
contract BuyBackAndLock {
    constructor() {
        DEPLOYMENT_TIME = block.timestamp;
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    using SafeERC20 for IERC20;

    uint256 private immutable DEPLOYMENT_TIME;

    IERC20 private constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // WETH on Arbitrum
    IERC20 private constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    address private constant TREASURY = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    uint256 private constant PRICE_PRECISION = 1e18;
    uint256 private constant START_PRICE_PSM_IN_WETH = 2.5e11; // 0.000_000_25 PSM/WETH
    uint256 private constant MAX_PRICE_PSM_IN_WETH = 1e12; // 0.000_001 PSM/WETH
    uint256 private constant PRICE_INCREASE_PER_SECOND = 5946; // reach max price after 4 years

    uint256 public constant PSM_TOTAL_SUPPLY = 10_000_000_000 * 1e18;

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event SoldAndLockedPSM(address indexed user, uint256 amountLockedPSM, uint256 amountReceivedWETH);
    event SurplusWithdrawn(uint256 amountWETH);

    ////////////////////////////////
    // Write Functions
    ////////////////////////////////
    ///@notice Allow users to sell PSM to the contract for WETH
    ///@dev The price in WETH increases over time
    ///@dev PSM can only be sold if the contract holds sufficient WETH. First come first serve
    function sellPSM(uint256 _amount) external {
        ///@dev Input validation
        if (_amount == 0) revert InvalidAmount();

        uint256 receivedWETH = quoteSellPSM(_amount);

        ///@dev Check if the contract has sufficient WETH
        uint256 balanceWETH = WETH.balanceOf(address(this));
        if (receivedWETH > balanceWETH) revert InsufficientWETH();

        ///@dev Transfer PSM from the user to the contract and WETH from the contract to the user
        PSM.transferFrom(msg.sender, address(this), _amount);
        WETH.safeTransfer(msg.sender, receivedWETH);

        ///@dev Emit event that PSM was sold
        emit SoldAndLockedPSM(msg.sender, _amount, receivedWETH);
    }

    ///@notice Allow the treasury to withdraw surplus WETH that is not needed for buying back PSM
    function withdrawSurplusWETH() external {
        ///@dev Ensure only the treasury can withdraw
        if (msg.sender != TREASURY) revert NotAuthorized();

        ///@dev Check that there is surplus WETH that can be withdrawn
        uint256 surplusWETH = getSurplusWETH();
        if (surplusWETH == 0) revert NoSurplusWETH();

        ///@dev Withdraw the surplus to the treasury
        WETH.safeTransfer(TREASURY, surplusWETH);

        ///@dev Emit the event that the surplus was withdrawn
        emit SurplusWithdrawn(surplusWETH);
    }

    ////////////////////////////////
    // Read Functions
    ////////////////////////////////
    ///@notice Calculate the current internal buyback price of PSM in WETH
    ///@dev The price is scaled by 1e18
    ///@dev The price cannot exceed the maximum price
    function _getPriceScaled() private view returns (uint256 price) {
        uint256 timePassed = block.timestamp - DEPLOYMENT_TIME;

        uint256 priceUnchecked = timePassed * PRICE_INCREASE_PER_SECOND + START_PRICE_PSM_IN_WETH;

        price = (priceUnchecked > MAX_PRICE_PSM_IN_WETH) ? MAX_PRICE_PSM_IN_WETH : priceUnchecked;
    }

    ///@notice Calculate the amount of WETH a user receives for a defined input amount of PSM
    ///@dev This function does not check if the exchange can be executed or not due to insufficient WETH balance
    ///@dev Always return a value according to input and current price
    function quoteSellPSM(uint256 _amount) public view returns (uint256 receivedWETH) {
        ///@dev Input validation
        if (_amount == 0) revert InvalidAmount();

        ///@dev Calcaulte the required WETH amount to match the input PSM
        uint256 price = _getPriceScaled();
        uint256 requiredWETH = (_amount * price) / PRICE_PRECISION;

        ///@dev Ensure that some WETH value is returned after precision cut-off
        if (requiredWETH == 0) revert AmountTooLow();

        ///@dev Return the amount of WETH the user will receive
        receivedWETH = requiredWETH;
    }

    ///@notice Calculate the amount of PSM that the contract can buy with its current WETH balance
    function getCapacityPSM() public view returns (uint256 capacityPSM) {
        uint256 balanceWETH = WETH.balanceOf(address(this));
        uint256 price = _getPriceScaled();

        capacityPSM = (balanceWETH * PRICE_PRECISION) / price;
    }

    ///@notice Calculate the amount of WETH in this contract that is not needed for repurchasing PSM
    ///@dev If there is no surplus, return 0
    function getSurplusWETH() public view returns (uint256 surplusWETH) {
        uint256 balanceWETH = WETH.balanceOf(address(this));
        uint256 balancePSM = PSM.balanceOf(address(this));

        uint256 repurchaseAmountPSM = (PSM_TOTAL_SUPPLY > balancePSM) ? PSM_TOTAL_SUPPLY - balancePSM : 0;
        uint256 reservedWETH = quoteSellPSM(repurchaseAmountPSM);

        surplusWETH = (balanceWETH > reservedWETH) ? balanceWETH - reservedWETH : 0;
    }
}
