// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotBeneficiary();
error ZeroBalance();
error NullAddress();
error InvalidUnlockTime();
error TimelockActive();

/// @title The SimpleVesting smart contract allows the beneficiary to claim any token after a set time
/// @author Possum Labs
/// @notice This contract collects ERC20 tokens and allows the beneficiary to withdraw them after the unlock time
/* The beneficiary is specified on deployment of this contract.
/* The beneficiary can change the beneficiary address.
/* The unlock time is fixed at deployment
*/
contract SimpleVesting {
    constructor(address _beneficiary, uint256 _unlockTime) {
        if (_beneficiary == address(0)) revert NullAddress();
        if (_unlockTime < block.timestamp) revert InvalidUnlockTime();

        beneficiary = _beneficiary;
        UNLOCK_TIME = _unlockTime;
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    using SafeERC20 for IERC20;

    uint256 public immutable UNLOCK_TIME; // the time after which tokens can be withdrawn
    address public beneficiary;

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event Claimed(address token, uint256 amount);
    event BeneficiaryChanged(address oldBeneficiary, address newBeneficiary);

    ////////////////////////////////
    // Write Functions
    ////////////////////////////////
    /// @notice Allows the current beneficiary to change the beneficiary address
    function changeBeneficiary(address _newBeneficiary) external {
        /// Checks
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (_newBeneficiary == address(0)) revert NullAddress();

        /// Effects
        beneficiary = _newBeneficiary;

        /// Interactions
        emit BeneficiaryChanged(msg.sender, beneficiary);
    }

    /// @notice Allows the beneficiary to claim any token after the unlock time has passed
    function claim(address _token) external {
        /// Checks
        if (block.timestamp < UNLOCK_TIME) revert TimelockActive();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        /// Effects

        /// Interactions
        token.safeTransfer(msg.sender, balance);

        emit Claimed(_token, balance);
    }
}
