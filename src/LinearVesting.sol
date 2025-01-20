// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotBeneficiary();
error ZeroTransfer();
error ZeroUnlock();
error NullAddress();

contract LinearVesting {
    constructor(address _beneficiary, address _vestingToken, uint256 _unlockPerSecond) {
        if (_beneficiary == address(0)) revert NullAddress();
        if (_vestingToken == address(0)) revert NullAddress();
        if (_unlockPerSecond == 0) revert ZeroUnlock();

        beneficiary = _beneficiary;
        vestingToken = IERC20(_vestingToken);
        unlockPerSecond = _unlockPerSecond;
        start = block.timestamp;
    }

    using SafeERC20 for IERC20;

    address public beneficiary;
    IERC20 public vestingToken;
    uint256 public unlockPerSecond;
    uint256 public start;
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
    ///@return unlocked The total amount of unlocked tokens
    function totalUnlocked() public view returns (uint256 unlocked) {
        unlocked = (block.timestamp - start) * unlockPerSecond;
    }

    /// @notice Allow the beneficiary to claim tokens up to the current unlock limit
    ///@dev Any token aside from the vesting token can be withdrawn without limitations
    function claim(address _token) external {
        if (msg.sender != beneficiary) revert NotBeneficiary();

        uint256 balance;
        uint256 transferAmount;

        if (_token == address(vestingToken)) {
            uint256 unlocked = totalUnlocked();
            balance = vestingToken.balanceOf(address(this));

            uint256 claimable = unlocked - claimed;
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
