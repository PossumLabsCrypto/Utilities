// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error NotBeneficiary();
error IsActive();
error Deactivated();
error NotOwner();
error IntervalNotComplete();
error ZeroBalance();

/// @title The Claimer chunks PSM distributions to follow a specific cadence
/// @author Possum Labs
/// @notice This contract collects PSM and allows the beneficiary to withdraw them in bulk once every so often
/* The beneficiary is specified on deployment of this contract. 1 contract per beneficiary.
/* The beneficiary can change the beneficiary address.
/* The interval in which PSM can be withdrawn by the beneficiary is fixed at deployment.
/* The owner can deactivate the contract.
/* When deactivated, anyone can withdraw any token from the contract.
*/
contract Claimer {
    constructor(address _beneficiary, uint256 _claimInterval) {
        beneficiary = _beneficiary;
        claimInterval = _claimInterval;
        nextClaimTime = block.timestamp + claimInterval;
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    IERC20 private constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    address private constant OWNER = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    address public beneficiary;
    uint256 public claimInterval;
    uint256 public nextClaimTime;

    uint256 public lastClaimedAmount; // info only
    uint256 public totalClaimedAmount; // info only

    bool public isDeactivated;

    ////////////////////////////////
    // Functions
    ////////////////////////////////
    /// @notice Allows the beneficiary to claim all PSM in this contract if the interval has passed
    function claim() external {
        if (msg.sender != beneficiary) revert NotBeneficiary();

        uint256 time = block.timestamp;
        if (nextClaimTime > time) revert IntervalNotComplete();

        nextClaimTime = time + claimInterval;
        uint256 balancePSM = PSM.balanceOf(address(this));

        if (balancePSM == 0) revert ZeroBalance();

        lastClaimedAmount = balancePSM;
        totalClaimedAmount += balancePSM;

        PSM.transfer(beneficiary, balancePSM);
    }

    /// @notice Calculates and returns the seconds until the next claim can be executed
    function secondsUntilNextClaim() external view returns (uint256 duration) {
        duration = (nextClaimTime <= block.timestamp) ? 0 : nextClaimTime - block.timestamp;
    }

    /// @notice Allows the current beneficiary to change the beneficiary address
    function changeBeneficiary(address _newBeneficiary) external {
        if (msg.sender != beneficiary) revert NotBeneficiary();

        beneficiary = _newBeneficiary;
    }

    /// @notice Allows the owner to deactivate the contract, rendering it useless
    /// @dev When calling this function, remaining PSM tokens are sent to owner
    function deactivate() external {
        if (isDeactivated == true) revert Deactivated();
        if (msg.sender != OWNER) revert NotOwner();

        isDeactivated = true;
        uint256 balance = PSM.balanceOf(address(this));

        if (balance > 0) {
            PSM.transfer(OWNER, balance);
        }
    }

    /// @notice Allows anyone to withdraw any token if the contract is deactivated
    function extractToken(address _token) external {
        if (isDeactivated == false) revert IsActive();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));

        if (balance == 0) revert ZeroBalance();

        token.transfer(msg.sender, balance);
    }
}
