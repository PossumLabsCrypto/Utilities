// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRamsesGauge} from "./interfaces/IRamsesGauge.sol";

error ZeroBalance();
error NullAddress();
error WrongToken();
error NotDeployer();

/// @title RamsesIncentivizer allows for accumulating tokens & permissionless bribing of a specific Gauge on Ramses
/// @author Possum Labs
/// @notice This contract collects ERC20 tokens and allows anyone to forward them to a specific Ramses Gauge as bribe.
/* The Gauge is specified on deployment of this contract.
/* The primary purpose of this contract is to receive PSM from the Possum Core for the purpose of Liquidity Mining on Ramses
/* Anyone can sweep the balance to Ramses so that the bribing process is permissionless
*/
contract RamsesIncentivizer {
    constructor(address _GAUGE) {
        if (_GAUGE == address(0)) revert NullAddress();

        GAUGE = IRamsesGauge(_GAUGE);
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    IRamsesGauge public immutable GAUGE;
    address private constant PSM_ADDRESS = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    address private immutable DEPLOYER = 0xbFF0b8CcD7ebA169107bbE72426dB370407C8f2D;
    IERC20 private constant PSM = IERC20(PSM_ADDRESS);
    uint256 private constant MAX_UINT = type(uint256).max;

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event TransferredTokensToGauge(address token, uint256 amount);

    ////////////////////////////////
    // Write Functions
    ////////////////////////////////
    /// @notice Approves PSM to be spent by the Ramses Gauge
    function approvePSM() external {
        PSM.approve(address(GAUGE), MAX_UINT);
    }

    /// @notice Transfers all PSM from this contract as incentives to the specified Gauge on Ramses
    function sweepPSMToGauge() external {
        /// Checks
        uint256 balance = PSM.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        /// Effects

        /// Interactions
        GAUGE.notifyRewardAmount(PSM_ADDRESS, balance);

        emit TransferredTokensToGauge(PSM_ADDRESS, balance);
    }

    /// @notice Transfers any non-PSM balance from this contract as incentives to the specified Gauge on Ramses
    function sweepTokenToGauge(address _token) external {
        /// Checks
        if (_token == address(0)) revert NullAddress();
        if (_token == PSM_ADDRESS) revert WrongToken();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        /// Effects

        /// Interactions
        token.approve(address(GAUGE), MAX_UINT);
        GAUGE.notifyRewardAmount(_token, balance);

        emit TransferredTokensToGauge(_token, balance);
    }

    /// @notice Allows the deployer to withdraw all PSM in case the Gauge becomes dysfunctional, affecting this contract
    function rescuePSM() external {
        /// Checks
        if (msg.sender != DEPLOYER) revert NotDeployer();
        uint256 balance = PSM.balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        /// Effects

        /// Interactions
        PSM.transfer(DEPLOYER, balance);
    }
}
