// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotBeneficiary();
error ZeroBalance();
error NullAddress();
error InvalidUnlockTime();
error TimelockActive();

/// @title The CliffVesting smart contract allows the owner to claim any token after a set time
/// @author Possum Labs
/// @notice This contract collects ERC20 tokens and allows the owner to withdraw them after the unlock time
/* The owner is specified on deployment of this contract.
/* The owner can change the owner address.
/* The unlock time is fixed at deployment
*/
contract CliffVesting {
    constructor(address _owner, uint256 _unlockTime) {
        if (_owner == address(0)) revert NullAddress();
        if (_unlockTime < block.timestamp) revert InvalidUnlockTime();

        owner = _owner;
        UNLOCK_TIME = _unlockTime;
    }

    using SafeERC20 for IERC20;

    uint256 public immutable UNLOCK_TIME; // the time after which tokens can be withdrawn
    address public owner;

    event Claimed(address token, uint256 amount);
    event OwnerChanged(address oldOwner, address newOwner);

    /// @notice Allows the current owner to change the owner address
    function changeBeneficiary(address _newOwner) external {
        if (msg.sender != owner) revert NotBeneficiary();
        if (_newOwner == address(0)) revert NullAddress();

        owner = _newOwner;

        emit OwnerChanged(msg.sender, owner);
    }

    /// @notice Allows the owner to claim any token after the unlock time has passed
    function claim(address _token) external {
        if (msg.sender != owner) revert NotBeneficiary();
        if (block.timestamp < UNLOCK_TIME) revert TimelockActive();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        token.safeTransfer(msg.sender, balance);

        emit Claimed(_token, balance);
    }
}
