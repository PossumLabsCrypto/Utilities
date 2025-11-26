// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotBeneficiary();
error ZeroTransfer();
error ZeroUnlock();
error NullAddress();
error InvalidTime();

contract LinearVesting {
    constructor(address _beneficiary, address _vestingToken, uint256 _unlockPerMonth, uint256 _startTime) {
        if (_beneficiary == address(0)) revert NullAddress();
        if (_vestingToken == address(0)) revert NullAddress();
        if (_unlockPerMonth == 0) revert ZeroUnlock();
        if (_startTime < block.timestamp) revert InvalidTime();

        beneficiary = _beneficiary;
        vestingToken = IERC20(_vestingToken);
        unlockPerMonth = _unlockPerMonth;
        unlockPerSecond = unlockPerMonth / (60 * 60 * 24 * 30);
        start = _startTime;
    }

    using SafeERC20 for IERC20;

    IERC20 public immutable vestingToken;
    uint256 public immutable unlockPerMonth;
    uint256 private immutable unlockPerSecond;
    uint256 public immutable start;

    address public beneficiary;
    uint256 public claimed;

    event Claimed(address token, uint256 amount);
    event BeneficiaryChanged(address oldBeneficiary, address newBeneficiary);

    /// @notice Allow the current beneficiary to change the beneficiary address
    function changeBeneficiary(address _newBeneficiary) external {
        /// Checks
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (_newBeneficiary == address(0)) revert NullAddress();

        /// Effects
        beneficiary = _newBeneficiary;

        /// Interactions
        emit BeneficiaryChanged(msg.sender, beneficiary);
    }

    ///@notice Calculate the total amount of unlocked tokens
    ///@return claimable The number of claimable vesting tokens ignoring balance constraints
    function pendingClaim() public view returns (uint256 claimable) {
        uint256 unlocked = (block.timestamp < start) ? 0 : (block.timestamp - start) * unlockPerSecond;

        claimable = unlocked - claimed;
    }

    /// @notice Allow the beneficiary to claim tokens up to the pending claim
    ///@dev Any token aside from the vesting token can be withdrawn without limitations
    function claim(address _token) external {
        if (msg.sender != beneficiary) revert NotBeneficiary();

        uint256 balance;
        uint256 transferAmount;

        if (_token == address(vestingToken)) {
            balance = vestingToken.balanceOf(address(this));
            uint256 claimable = pendingClaim();

            transferAmount = (claimable > balance) ? balance : claimable;
            if (transferAmount == 0) revert ZeroTransfer();

            claimed += transferAmount;
            vestingToken.safeTransfer(beneficiary, transferAmount);
        } else {
            IERC20 token = IERC20(_token);

            balance = token.balanceOf(address(this));
            transferAmount = balance;
            if (transferAmount == 0) revert ZeroTransfer();

            token.safeTransfer(beneficiary, transferAmount);
        }

        emit Claimed(_token, transferAmount);
    }
}
