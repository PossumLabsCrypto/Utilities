// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// ============================================
error NotOwner();
error NullAddress();
error ZeroBalance();
error InvalidAmount();
error InvalidDeadline();
error InvalidToken();
error InsufficientReceived();
error DeadlineExpired();
error ViolatedInvariant();
error FailedToSendNativeToken();
error ZeroFees();
// ============================================

contract LinearBondingCurve {
    constructor(address _owner) {
        if (_owner == address(0)) revert NullAddress();
        owner = _owner;
        PRICE_RANGE = MAX_PRICE - MIN_PRICE;
        MID_PRICE = (MAX_PRICE + MIN_PRICE) / 2;
    }

    using SafeERC20 for IERC20;

    uint256 public constant SWAP_FEE = 50; // 0.05% fee, with 4 decimals (i.e., 50 = 0.05%)
    uint256 public constant MAX_PRICE = 49_000_000e18; // 1 ETH = 49M PSM, with 18 decimals
    uint256 public constant MIN_PRICE = 1_000_000e18; // 1 ETH = 1M PSM, with 18 decimals
    uint256 private immutable PRICE_RANGE; // price range of the bonding curve, with 18 decimals
    uint256 private immutable MID_PRICE; // midpoint price of the bonding curve, with 18 decimals
    IERC20 private constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);

    address public owner;

    uint256 psmSupply; // Maximum PSM that can be sold through the bonding curve
    uint256 psmSold; // Total PSM sold through the bonding curve

    uint256 ethGoal; // Total ETH goal for the bonding curve
    uint256 ethPurchased; // Total ETH purchased through the bonding curve

    uint256 public accruedFeeEth;
    uint256 public accruedFeePsm;

    uint256 public lastPrice; // last price of ETH in PSM terms, with 18 decimals

    event OwnerChanged(address oldOwner, address newOwner);
    event SuppliedToBondingCurve(uint256 amount);
    event Sweeped(address token, uint256 amount);

    // ============================================
    // ==            OWNER FUNCTIONS             ==
    // ============================================
    function changeOwner(address _newOwner) external {
        checkOwner(msg.sender);
        if (_newOwner == address(0)) revert NullAddress();

        owner = _newOwner;

        emit OwnerChanged(msg.sender, owner);
    }

    function withdraw(address _token) external {
        checkOwner(msg.sender);
        if (_token == address(0)) revert InvalidToken();
        if (_token == address(PSM)) revert InvalidToken();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        token.safeTransfer(owner, balance);

        emit Sweeped(_token, balance);
    }

    function supplyPsmToBondingCurve(uint256 _amount) external {
        checkOwner(msg.sender);
        if (_amount == 0) revert InvalidAmount();

        psmSupply += _amount;
        ethGoal = (psmSupply * 1e18) / MID_PRICE; // update total ETH goal based on new PSM supply
        if (ethGoal < 1e18) revert InvalidAmount(); // Ensure at least 1 ETH total purchase

        // Update last price based on new supply and sold amounts (price drops on added supply)
        lastPrice = (psmSupply == 0) ? MAX_PRICE : MAX_PRICE - ((PRICE_RANGE * psmSold) / psmSupply);

        PSM.safeTransferFrom(msg.sender, address(this), _amount);

        emit SuppliedToBondingCurve(_amount);
    }

    function sweepAndReset() external {
        // CHECKS
        checkOwner(msg.sender);

        uint256 balancePSM = PSM.balanceOf(address(this));
        if (balancePSM == 0) revert ZeroBalance();

        uint256 balanceETH = address(this).balance;
        if (balanceETH == 0) revert ZeroBalance();

        // EFFECTS
        psmSupply = 0; // reset supply to 0 since we're sweeping all PSM
        psmSold = 0; // reset sold to 0 since we're sweeping all PSM
        ethGoal = 0; // reset total ETH goal
        lastPrice = 0; // reset last price since we're sweeping all ETH and PSM

        // INTERACTIONS
        PSM.safeTransfer(owner, balancePSM);

        address payable ownerPayable = payable(owner);
        (bool success,) = ownerPayable.call{value: balanceETH}("");
        require(success, "ETH transfer failed");

        emit Sweeped(address(PSM), balancePSM);
        emit Sweeped(address(0), balanceETH);
    }

    function collectFees() external {
        // CHECKS
        checkOwner(msg.sender);

        // Cache fee trackers & ensure positive value of at least one
        uint256 feeETH = accruedFeeEth;
        uint256 feePSM = accruedFeePsm;
        if (feeETH == 0 && feePSM == 0) revert ZeroFees();

        // EFFECTS
        // Reset fee trackers
        accruedFeeEth = 0;
        accruedFeePsm = 0;

        // INTERACTIONS
        PSM.safeTransfer(owner, feePSM);

        address payable ownerPayable = payable(owner);
        (bool success,) = ownerPayable.call{value: feeETH}("");
        if (!success) revert FailedToSendNativeToken();
    }

    function checkOwner(address _caller) internal view {
        if (_caller != owner) revert NotOwner();
    }

    // ============================================
    // ==            SWAPS PSM <> ETH            ==
    // ============================================
    function quoteSwap(address _tokenIn, uint256 _amountIn)
        public
        view
        returns (uint256 amountOut, uint256 amountRefunded)
    {
        // CHECKS
        if (_tokenIn != address(PSM) && _tokenIn != address(0)) revert InvalidToken();
        if (_amountIn == 0) revert InvalidAmount();

        // EFFECTS
        uint256 grossAmountIn;
        uint256 netAmountIn;
        uint256 feeAmount;

        if (_tokenIn == address(0)) {
            // Swap ETH -> PSM
            (grossAmountIn, feeAmount) = getGrossAmountAndFee(address(0), _amountIn);

            netAmountIn = grossAmountIn - feeAmount; // calculate net amount in after fee
            amountRefunded = (grossAmountIn < _amountIn) ? _amountIn - grossAmountIn : 0; // refund any ETH that cannot be absorbed

            amountOut = (psmSupply * netAmountIn) / ethGoal; // calculate PSM output based on reserve ratios
        } else {
            // Calculate swap PSM -> ETH
            (grossAmountIn, feeAmount) = getGrossAmountAndFee(address(PSM), _amountIn);

            netAmountIn = grossAmountIn - feeAmount; // calculate net amount in after fee
            amountRefunded = (grossAmountIn < _amountIn) ? _amountIn - grossAmountIn : 0; // refund any PSM that cannot be absorbed

            amountOut = (ethGoal * netAmountIn) / psmSupply; // calculate ETH output based on reserve ratios
        }
    }

    function swap(address _tokenIn, uint256 _amountIn, uint256 _minReceived, uint256 _deadline) external payable {
        // CHECKS
        // Get ETH amount from Tx & balanceBefore
        if (_tokenIn == address(0)) {
            _amountIn = msg.value;
        }

        if (_deadline < block.timestamp) revert DeadlineExpired();

        (uint256 received, uint256 refund) = quoteSwap(_tokenIn, _amountIn);
        if (received < _minReceived) revert InsufficientReceived();

        // EFFECTS
        uint256 grossAmountIn = _amountIn - refund;
        uint256 fee = (grossAmountIn * SWAP_FEE) / 10000;
        uint256 netAmountIn = grossAmountIn - fee;

        // update psmSold, ethPurchased, lastPrice, accrued Fee
        if (_tokenIn == address(0)) {
            ethPurchased += netAmountIn;
            psmSold += received;

            lastPrice = MAX_PRICE - (PRICE_RANGE * psmSold) / psmSupply;
        } else {
            ethPurchased = (ethPurchased < received) ? 0 : ethPurchased - received; // guarantee no underflow
            psmSold = (psmSold < netAmountIn) ? 0 : psmSold - netAmountIn; //guarantee no underflow

            lastPrice = MAX_PRICE - (PRICE_RANGE * psmSold) / psmSupply;
        }

        // INTERACTIONS
        if (_tokenIn == address(0)) {
            // Verify balance received
            uint256 ethBalanceAfter = address(this).balance;
            if (ethBalanceAfter < ethPurchased) revert ViolatedInvariant();

            // Send PSM to the user
            PSM.safeTransfer(msg.sender, received);
        } else {
            // Verify balance received
            uint256 psmBalanceAfter = address(this).balance;
            if (psmBalanceAfter < (psmSupply - psmSold)) revert ViolatedInvariant();

            // Send ETH to the user
            (bool sent,) = payable(msg.sender).call{value: received}("");
            if (!sent) revert FailedToSendNativeToken();
        }
    }

    // ============================================
    // ==               INTERNAL                 ==
    // ============================================
    function getGrossAmountAndFee(address _token, uint256 _amountIn)
        private
        view
        returns (uint256 grossAmountIn, uint256 feeAmount)
    {
        uint256 feeCoefficient = 10000e18 / (10000 - SWAP_FEE); // reversed fee multiplicator to calculate gross amount in from net amount in, with 18 decimals

        if (_token == address(0)) {
            uint256 ethCapacity = ((ethGoal - ethPurchased) * feeCoefficient) / 1e18;

            grossAmountIn = (_amountIn > ethCapacity) ? ethCapacity : _amountIn;
            feeAmount = (grossAmountIn * SWAP_FEE) / 10000; // calculate fee based on net amount in, with 18 decimals
            if (feeAmount == 0) revert InvalidAmount(); // ensure fee is not zero to prevent free swaps
        }

        if (_token == address(PSM)) {
            uint256 psmCapacity = (psmSold * feeCoefficient) / 1e18;

            grossAmountIn = (_amountIn > psmCapacity) ? psmCapacity : _amountIn;
            feeAmount = (grossAmountIn * SWAP_FEE) / 10000; // calculate fee based on net amount in, with 18 decimals
            if (feeAmount == 0) revert InvalidAmount(); // ensure fee is not zero to prevent free swaps
        }
    }

    // ============================================
    // ==               ACCEPT ETH               ==
    // ============================================
    receive() external payable {}

    fallback() external payable {}
}
