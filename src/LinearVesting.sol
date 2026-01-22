// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotOwner();
error ZeroTransfer();
error LowUnlock();
error NullAddress();
error InvalidTime();

contract LinearVesting {
    constructor(address _owner, address _vestingToken, uint256 _unlockPerMonth, uint256 _startTime) {
        if (_owner == address(0)) revert NullAddress();
        if (_vestingToken == address(0)) revert NullAddress();
        if (_unlockPerMonth < 1e18) revert LowUnlock(); // fool proofing against decimal misconfiguration
        if (_startTime < MIN_START_TIME) revert InvalidTime();

        owner = _owner;
        vestingToken = IERC20(_vestingToken);
        unlockPerMonth = _unlockPerMonth;
        unlockPerSecond = unlockPerMonth / (60 * 60 * 24 * 30);
        lastClaimTime = _startTime;
    }

    using SafeERC20 for IERC20;

    uint256 private constant MIN_START_TIME = 1701363600; // Nov 30th, 2023

    IERC20 public immutable vestingToken;
    uint256 public immutable unlockPerMonth;
    uint256 private immutable unlockPerSecond;

    uint256 public lastClaimTime;
    address public owner;

    /// @notice Allow the current beneficiary to change the beneficiary address
    function changeOwner(address _newOwner) external {
        /// Checks
        if (msg.sender != owner) revert NotOwner();
        if (_newOwner == address(0)) revert NullAddress();

        /// Effects
        owner = _newOwner;
    }

    ///@notice Calculate the amount of unlocked, claimable tokens
    ///@return claimable The number of claimable vesting tokens considering balance constraints
    function pendingClaim() public view returns (uint256 claimable) {
        uint256 balance = vestingToken.balanceOf(address(this));
        uint256 calc = (block.timestamp < lastClaimTime) ? 0 : (block.timestamp - lastClaimTime) * unlockPerSecond;

        claimable = (calc > balance) ? balance : calc;
    }

    /// @notice Allow the owner to claim vesting tokens up to the potential claim
    ///@dev Any token aside from the vesting token can be withdrawn without limitations
    function claim(address _token) external {
        if (msg.sender != owner) revert NotOwner();
        if (_token == address(0)) revert NullAddress();

        uint256 transferAmount;

        if (_token == address(vestingToken)) {
            transferAmount = pendingClaim();
            if (transferAmount == 0) revert ZeroTransfer();

            lastClaimTime = block.timestamp;
            vestingToken.safeTransfer(owner, transferAmount);
        } else {
            IERC20 token = IERC20(_token);
            transferAmount = token.balanceOf(address(this));
            if (transferAmount == 0) revert ZeroTransfer();

            token.safeTransfer(owner, transferAmount);
        }
    }
}
