// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IConvertHelper} from "./interfaces/IConvertHelper.sol";

error InsufficientBalance();
error InvalidAddress();
error InvalidAmount();
error InsufficientReward();
error NotDepositor();
error TimeNotPassed();
error CannotDecreaseFee();

/// @title Converter for PortalsV1 and V2 on Arbitrum
/// @author Possum Labs
/// @notice This contract allows users to deposit PSM to be used in the convert arbitrage of Portals
/* Users must deposit PSM in multiples of 100k and determine an exchange token and the desired exchange rate
/* Deposits and exchange conditions are registered in a public mapping to be queried by bots
/* if conditions are met, bots can execute arbitrage with tokens of depositors and receive an execution reward 
*/
contract Converter {
    constructor() {
        enabledTokens[address(USDC)] = true;
        enabledTokens[address(USDCE)] = true;
        enabledTokens[address(WETH)] = true;
        enabledTokens[address(WBTC)] = true;
        enabledTokens[address(ARB)] = true;
        enabledTokens[address(LINK)] = true;

        feeUpdateTime = block.timestamp;
    }

    using SafeERC20 for IERC20;

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    IERC20 public constant PSM = IERC20(0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5);
    IERC20 private constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 private constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 private constant ARB = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
    IERC20 private constant LINK = IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4);

    address private constant V1_HLP_PORTAL = 0x24b7d3034C711497c81ed5f70BEE2280907Ea1Fa;
    address private constant V2_USDC_PORTAL = 0x9167CFf02D6f55912011d6f498D98454227F4e16;
    address private constant V2_USDCE_PORTAL = 0xE8EfFf304D01aC2D9BA256b602D736dB81f20984;
    address private constant V2_ETH_PORTAL = 0xe771545aaDF6feC3815B982fe2294F7230C9c55b;
    address private constant V2_WBTC_PORTAL = 0x919B37b5f2f1DEd2a1f6230Bf41790e27b016609;
    address private constant V2_ARB_PORTAL = 0x523a93037c47Ba173E9080FE8EBAeae834c24082;
    address private constant V2_LINK_PORTAL = 0x51623b54753E07Ba9B3144Ba8bAB969D427982b6;

    address private constant PSM_TREASURY = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    IConvertHelper convertHelper = IConvertHelper(0xa94f0513b41e8C0c6E96B76ceFf2e28cAA3F5ebb);

    uint256 private constant MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 public constant PSM_AMOUNT_FOR_CONVERT = 100000 * 1e18; // 100k PSM to execute convert
    uint256 public constant ORDER_CREATION_FEE_PSM = 1000 * 1e18; // 1k PSM to avoid spam orders
    uint256 public feeUpdateTime; // time of last fee updating
    uint256 private constant SECONDS_PER_YEAR = 31536000; // seconds in a 365 day year
    uint256 public executionRewardPercent = 5;

    struct Order {
        address depositor;
        address tokenRequested;
        uint256 minReceivedPer100kPSM;
        uint256 psmDeposit;
    }

    mapping(uint256 orderID => Order) public orders; // order details for a given ID
    mapping(address => bool) public enabledTokens; // Yield tokens that can be retrieved from Portals

    uint256 public orderIndex; // the ID of the most recent order, i.e. sum of all orders ever generated

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event OrderCreated(address indexed depositor, uint256 indexed orderID);
    event OrderUpdated(uint256 indexed orderID, Order details);
    event ArbitrageExecuted(uint256 indexed orderID, address indexed tokenReceived, uint256 amount);

    ////////////////////////////////
    // depositor functions
    ////////////////////////////////
    /// @notice This function allows users to deposit multiples of 100k PSM to be used in arbitrage
    /// @dev User must specify a requested token address that is part of the allowed tokens mapping
    /// @dev User must set the amount of above specified token expected per exchanged 100k PSM
    /// @dev User must deposit a multiple of 100k PSM to avoid remainders
    /// @dev User must pay 1k PSM to create the order (Spam protection)
    function createOrder(address _tokenRequested, uint256 _minReceivedPer100kPSM, uint256 _amount) external {
        // Input validation
        if (!enabledTokens[_tokenRequested]) revert InvalidAddress();
        if (_minReceivedPer100kPSM == 0) revert InvalidAmount();
        if (_amount == 0 || _amount % PSM_AMOUNT_FOR_CONVERT > 0) revert InvalidAmount();

        address depositor = msg.sender;

        // Create a new Order struct and add to mapping
        Order storage newOrder = orders[orderIndex];
        newOrder.depositor = depositor;
        newOrder.tokenRequested = _tokenRequested;
        newOrder.minReceivedPer100kPSM = _minReceivedPer100kPSM;
        newOrder.psmDeposit = _amount;

        // Increase the Order Index to avoid overwriting old orders
        orderIndex++;

        // Pay the order fee of 1k PSM to the treasury (Spam protection)
        PSM.transferFrom(depositor, PSM_TREASURY, ORDER_CREATION_FEE_PSM);

        // transfer PSM deposit to contract
        PSM.transferFrom(depositor, address(this), _amount);

        // emit events
        emit OrderCreated(msg.sender, orderIndex - 1);
        emit OrderUpdated(orderIndex - 1, newOrder);
    }

    /// @notice This function allows users to increase their PSM deposit on an existing order
    /// @dev User must specify an owned order ID and the amount of PSM to add to the order
    /// @dev User must deposit a multiple of 100k PSM
    function increaseOrder(uint256 _orderID, uint256 _amount) external {
        // input validation - only the depositor can increase the order
        Order storage order = orders[_orderID];
        if (msg.sender != order.depositor) revert NotDepositor();
        if (_amount == 0 || _amount % PSM_AMOUNT_FOR_CONVERT > 0) revert InvalidAmount();

        // Increase Order amount
        order.psmDeposit += _amount;

        // Transfer PSM to top up the order
        PSM.transferFrom(msg.sender, address(this), _amount);

        // emit event that order was updated
        emit OrderUpdated(_orderID, order);
    }

    /// @notice This function allows users to withdraw PSM from an existing order
    /// @dev User must specify an owned order ID and the amount of PSM to withdraw from the order
    /// @dev User must withdraw a multiple of 100k PSM
    function decreaseOrder(uint256 _orderID, uint256 _amount) external {
        // input validation - only the depositor can decrease the order
        Order storage order = orders[_orderID];
        uint256 amount = _amount;
        if (msg.sender != order.depositor) revert NotDepositor();
        if (amount == 0 || amount % PSM_AMOUNT_FOR_CONVERT > 0) revert InvalidAmount();
        if (amount > order.psmDeposit) amount = order.psmDeposit;

        // Decrease order amount
        order.psmDeposit -= amount;

        // Transfer withdrawn tokens to depositor
        PSM.transfer(msg.sender, amount);

        // emit event that the order was updated
        emit OrderUpdated(_orderID, order);
    }

    ////////////////////////////////
    // Bot functions
    ////////////////////////////////
    /// @notice This function checks if the arbitrage conditions for a given order ID are met
    /// @dev Check if the arbitrage can be executed for sufficient rewards
    /// @dev Returns the amount of tokens received
    /// @dev Returns the portal address that this arbitrage order ID will interact with
    function checkArbitrage(uint256 _orderID)
        public
        view
        returns (bool canExecute, address portal, uint256 amountReceived)
    {
        // Check if Order has enough PSM deposited
        Order memory order = orders[_orderID];
        if (order.psmDeposit >= PSM_AMOUNT_FOR_CONVERT) {
            // Calculate the accumulated rewards of the related Portal
            // Get the related Portal address
            if (order.tokenRequested == address(USDC)) {
                amountReceived = convertHelper.V2_getRewards(V2_USDC_PORTAL);
                portal = V2_USDC_PORTAL;
            }
            if (order.tokenRequested == address(USDCE)) {
                uint256 rewardsV1 = convertHelper.V1_getRewardsUSDCE();
                uint256 rewardsV2 = convertHelper.V2_getRewards(V2_USDCE_PORTAL);
                amountReceived = (rewardsV1 > rewardsV2) ? rewardsV1 : rewardsV2;
                portal = (rewardsV1 > rewardsV2) ? V1_HLP_PORTAL : V2_USDCE_PORTAL;
            }
            if (order.tokenRequested == address(WETH)) {
                amountReceived = convertHelper.V2_getRewards(V2_ETH_PORTAL);
                portal = V2_ETH_PORTAL;
            }
            if (order.tokenRequested == address(WBTC)) {
                amountReceived = convertHelper.V2_getRewards(V2_WBTC_PORTAL);
                portal = V2_WBTC_PORTAL;
            }
            if (order.tokenRequested == address(ARB)) {
                amountReceived = convertHelper.V2_getRewards(V2_ARB_PORTAL);
                portal = V2_ARB_PORTAL;
            }
            if (order.tokenRequested == address(LINK)) {
                amountReceived = convertHelper.V2_getRewards(V2_LINK_PORTAL);
                portal = V2_LINK_PORTAL;
            }

            // Check if arbitrage can be executed after accounting for execution reward
            uint256 threshold = (order.minReceivedPer100kPSM * (100 + executionRewardPercent)) / 100;
            if (amountReceived >= threshold) {
                canExecute = true;
            }
        }
    }

    /// @notice This function executes the arbitrage of a certain order ID if conditions are met
    /// @dev Check if the arbitrage can be executed
    /// @dev Get the expected arbitrage token amount and Portal address to interact with
    /// @dev Calculate the reward for the executor
    /// @dev Update the order information, execute the arbitrage and send tokens to executor and depositor
    function executeArbitrage(address _recipient, uint256 _orderID) external {
        // check the arbitrage condition
        (bool canExecute, address portal, uint256 amountReceived) = checkArbitrage(_orderID);
        if (!canExecute) revert InsufficientReward();

        // Load order information
        Order storage order = orders[_orderID];

        // Update the Order information
        order.psmDeposit -= PSM_AMOUNT_FOR_CONVERT;

        // Check which Portal is targeted and execute arbitrage via the convertHelper contract
        if (portal == V1_HLP_PORTAL) convertHelper.V1_convertUSDCE(address(this), amountReceived);
        else convertHelper.V2_convert(portal, address(this), amountReceived);

        // Calculate arbitrage amount for depositor and rewards for executor
        uint256 executorReward = amountReceived - ((amountReceived * 100) / (100 + executionRewardPercent));
        uint256 arbitrageAmount = amountReceived - executorReward;

        // Send tokens to depositor and executor
        IERC20(order.tokenRequested).safeTransfer(_recipient, executorReward);
        IERC20(order.tokenRequested).safeTransfer(order.depositor, arbitrageAmount);

        // Emit event with updated Order information and execution of arbitrage
        emit OrderUpdated(_orderID, order);
        emit ArbitrageExecuted(_orderID, order.tokenRequested, arbitrageAmount);
    }

    ////////////////////////////////
    // Helper functions
    ////////////////////////////////
    /// @dev Allow spending of PSM by the ConvertHelper contract to execute the arbitrage
    function setApprovals() external {
        PSM.approve(address(convertHelper), MAX_UINT);
    }

    /// @dev Reduce the execution fee by 1% every year until it reaches 1%
    function updateExecutionFee() external {
        uint256 timePassed = block.timestamp - feeUpdateTime;
        if (timePassed < SECONDS_PER_YEAR) revert TimeNotPassed();
        if (executionRewardPercent == 1) revert CannotDecreaseFee();
        executionRewardPercent -= 1;
    }
}
