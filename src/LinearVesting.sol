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
    constructor(address _owner, address _vestingToken, uint256 _unlockPerMonth, uint256 _startTime) {
        if (_owner == address(0)) revert NullAddress();
        if (_vestingToken == address(0)) revert NullAddress();
        if (_unlockPerMonth == 0) revert ZeroUnlock();
        if (_startTime < MIN_START_TIME) revert InvalidTime();

        owner = _owner;
        vestingToken = IERC20(_vestingToken);
        unlockPerMonth = _unlockPerMonth;
        unlockPerSecond = unlockPerMonth / (60 * 60 * 24 * 30);
        start = _startTime;
    }

    using SafeERC20 for IERC20;

    uint256 private constant MIN_START_TIME = 1701363600; // Nov 30th, 2023

    IERC20 public immutable vestingToken;
    uint256 public immutable unlockPerMonth;
    uint256 private immutable unlockPerSecond;
    uint256 public immutable start;

    address public owner;
    uint256 public claimed;

    event Claimed(address token, uint256 amount);
    event BeneficiaryChanged(address oldBeneficiary, address newBeneficiary);

    /// @notice Allow the current beneficiary to change the beneficiary address
    function changeBeneficiary(address _newOwner) external {
        /// Checks
        if (msg.sender != owner) revert NotBeneficiary();
        if (_newOwner == address(0)) revert NullAddress();

        /// Effects
        owner = _newOwner;

        /// Interactions
        emit BeneficiaryChanged(msg.sender, _newOwner);
    }

    ///@notice Calculate the amount of unlocked, claimable tokens
    ///@return claimable The number of claimable vesting tokens ignoring balance constraints
    function pendingClaim() public view returns (uint256 claimable) {
        uint256 unlocked = (block.timestamp < start) ? 0 : (block.timestamp - start) * unlockPerSecond;

        claimable = unlocked - claimed;
    }

    /// @notice Allow the beneficiary to claim vesting tokens up to the pending claim
    ///@dev Any token aside from the vesting token can be withdrawn without limitations
    function claim(address _token) external {
        if (msg.sender != owner) revert NotBeneficiary();

        uint256 balance;
        uint256 transferAmount;

        if (_token == address(vestingToken)) {
            balance = vestingToken.balanceOf(address(this));
            uint256 claimable = pendingClaim();

            transferAmount = (claimable > balance) ? balance : claimable;
            if (transferAmount == 0) revert ZeroTransfer();

            claimed += transferAmount;
            vestingToken.safeTransfer(owner, transferAmount);
        } else {
            IERC20 token = IERC20(_token);

            balance = token.balanceOf(address(this));
            transferAmount = balance;
            if (transferAmount == 0) revert ZeroTransfer();

            token.safeTransfer(owner, transferAmount);
        }

        emit Claimed(_token, transferAmount);
    }
}
