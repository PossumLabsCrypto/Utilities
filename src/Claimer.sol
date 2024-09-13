// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NotBeneficiary();
error IsActive();
error Deactivated();
error NotOwner();
error ClaimWindowNotOpen();
error ZeroBalance();
error NullAddress();
error InvalidCycle();
error InvalidClaimTime();

/// @title The Claimer contract bundles PSM distributions to follow a claiming cycle
/// @author Possum Labs
/// @notice This contract collects PSM and allows the beneficiary to withdraw them in bulk once every cycle
/* The beneficiary is specified on deployment of this contract. 1 contract per beneficiary.
/* The beneficiary can change the beneficiary address.
/* The interval in which PSM can be withdrawn by the beneficiary is fixed at deployment.
/* The claim window is 24 hours after which the beneficiary needs to wait to the next cycle.
/* The owner can deactivate the contract, sending all PSM to the beneficiary.
/* When deactivated, anyone can withdraw any token from the contract.
*/
contract Claimer {
    constructor(address _beneficiary, uint256 _claimInterval, uint256 _firstClaimTime) {
        if (_beneficiary == address(0)) revert NullAddress();
        if (_claimInterval < MIN_CYCLE_LENGTH) revert InvalidCycle();
        if (_claimInterval > MAX_CYCLE_LENGTH) revert InvalidCycle();
        if (_firstClaimTime < block.timestamp) revert InvalidClaimTime();

        beneficiary = _beneficiary;
        CLAIM_INTERVAL = _claimInterval;
        FIRST_CLAIM_TIME = _firstClaimTime;
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    using SafeERC20 for IERC20;

    IERC20 private constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    address private constant OWNER = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;
    uint256 private constant MIN_CYCLE_LENGTH = 604800; // 7 days
    uint256 private constant MAX_CYCLE_LENGTH = 7776000; // 90 days

    uint256 public constant CLAIM_WINDOW = 86400; // 24 hours
    uint256 public immutable CLAIM_INTERVAL;
    uint256 public immutable FIRST_CLAIM_TIME;

    address public beneficiary;

    uint256 public lastClaimedAmount; // info only
    uint256 public totalClaimedAmount; // info only

    bool public isDeactivated;

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event ContractDeactivated(address thisContract);
    event TokenExtracted(address token, uint256 amount);
    event Claimed(uint256 amount);
    event BeneficiaryChanged(address oldBeneficiary, address newBeneficiary);

    ////////////////////////////////
    // Write Functions
    ////////////////////////////////
    /// @notice Allows the current beneficiary to change the beneficiary address
    function changeBeneficiary(address _newBeneficiary) external {
        /// Checks
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (isDeactivated == true) revert Deactivated();
        if (_newBeneficiary == address(0)) revert NullAddress();

        /// Effects
        beneficiary = _newBeneficiary;

        /// Interactions
        emit BeneficiaryChanged(msg.sender, beneficiary);
    }

    /// @notice Allows the beneficiary to claim all PSM in this contract if the interval has passed
    function claim() external {
        /// Checks
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (isDeactivated == true) revert Deactivated();

        uint256 nextClaim = secondsToNextClaimWindow();
        if (nextClaim > 0) revert ClaimWindowNotOpen();

        uint256 balancePSM = PSM.balanceOf(address(this));
        if (balancePSM == 0) revert ZeroBalance();

        /// Effects
        lastClaimedAmount = balancePSM;
        totalClaimedAmount += balancePSM;

        /// Interactions
        PSM.safeTransfer(beneficiary, balancePSM);

        emit Claimed(balancePSM);
    }

    /// @notice Allows the owner to deactivate the contract, rendering it useless
    /// @dev When calling this function, remaining PSM tokens are sent to the beneficiary
    function deactivate() external {
        /// Checks
        if (msg.sender != OWNER) revert NotOwner();
        if (isDeactivated == true) revert Deactivated();

        /// Effects
        isDeactivated = true;
        uint256 balance = PSM.balanceOf(address(this));

        /// Interactions
        if (balance > 0) {
            PSM.safeTransfer(beneficiary, balance);
        }

        emit ContractDeactivated(address(this));
    }

    /// @notice Allows anyone to withdraw any token if the contract is deactivated to avoid stuck tokens
    function extractToken(address _token) external {
        /// Checks
        if (!isDeactivated) revert IsActive();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));

        if (balance == 0) revert ZeroBalance();

        /// Effects

        /// Interactions
        token.safeTransfer(msg.sender, balance);

        emit TokenExtracted(_token, balance);
    }

    ////////////////////////////////
    // Read Functions
    ////////////////////////////////
    /// @notice Calculates and returns the number of seconds until the next claim window
    /// @dev Returns zero when the current claim window is active
    function secondsToNextClaimWindow() public view returns (uint256 duration) {
        uint256 timePassed = block.timestamp - FIRST_CLAIM_TIME;
        uint256 cycleCounter = timePassed / CLAIM_INTERVAL;

        uint256 lastClaimWindowStart = FIRST_CLAIM_TIME + CLAIM_INTERVAL * cycleCounter;
        uint256 lastClaimWindowEnd = lastClaimWindowStart + CLAIM_WINDOW;
        uint256 nextClaimWindowStart = FIRST_CLAIM_TIME + CLAIM_INTERVAL * (cycleCounter + 1);

        duration = (block.timestamp > lastClaimWindowEnd) ? nextClaimWindowStart : 0;
    }
}
