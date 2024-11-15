// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH_ARB} from "src/interfaces/IWETH_ARB.sol";

error ActiveAuction();
error NotAuctionable();
error ZeroBalance();
error ZeroSupplied();

/// @title The Claimer contract bundles PSM distributions to follow a claiming cycle
/// @author Possum Labs
/// @notice This contract collects PSM and allows the beneficiary to withdraw them in bulk once every cycle
contract Auctioneer {
    constructor(address _accumulatedToken, address _recipient) {
        RECIPIENT = _recipient;
        ACCUMULATED_TOKEN = IERC20(_accumulatedToken);
    }

    ////////////////////////////////
    // Variables
    ////////////////////////////////
    using SafeERC20 for IERC20;

    IWETH_ARB private constant WETH = IWETH_ARB(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // WETH on Arbitrum

    IERC20 private immutable ACCUMULATED_TOKEN;
    address private immutable RECIPIENT;
    uint256 public constant AUCTION_DURATION = 604800; // 1 week

    uint256 public currentAuctionID;

    struct Auction {
        address asset;
        uint256 amountToAuction;
        uint256 totalSuppliedToken;
        uint256 endTime;
        uint256 claimedAssets;
    }

    mapping(address asset => uint256 claimable) public assetClaimsTotal; // claimable amount of a specific asset over all auctions
    mapping(address asset => uint256 lastAuction) public lastAuctionForAsset; // AuctionID of the most recent auction of this asset

    mapping(uint256 auctionID => Auction info) public auctionInfo;
    mapping(uint256 auctionID => bool flag) public isSettled;

    mapping(address user => uint256 userClaimed) public userClaimedAssets;
    mapping(address user => mapping(uint256 auctionID => uint256 suppliedToken)) public userSuppliedTokens_perAuction;

    ////////////////////////////////
    // Events
    ////////////////////////////////
    event AuctionStarted(
        uint256 indexed auctionID, address indexed asset, uint256 indexed auctionEndTime, uint256 amountToAuction
    );
    event AuctionSettled(
        uint256 indexed auctionID, address indexed asset, uint256 amountToAuction, uint256 totalSuppliedTokens
    );

    event PSM_SuppliedToAuction(
        uint256 indexed auctionID, address indexed asset, uint256 indexed auctionEndTime, uint256 suppliedTokens
    );

    ////////////////////////////////
    // Write Functions
    ////////////////////////////////
    /// @notice Start the auction for a specific asset
    function startAuction(address _asset) external {
        /// @dev Cached parameters
        address asset = _asset;
        uint256 time = block.timestamp;
        uint256 lastID = lastAuctionForAsset[asset];

        /// @dev Get the available balance of the asset to be sold in the auction
        uint256 amount = getAvailableAssets(asset);

        // Checks
        /// @dev Avoid auction of zero balances
        if (amount == 0) revert ZeroBalance();

        // Effects
        /// @dev Attempt to settle the previous auction of this asset to ensure only one auction per asset at a time
        /// @dev Fails if the previous auction of this asset is still ongoing
        if (!isSettled[lastID]) {
            settleAuction(lastID);
        }

        /// @dev Update the global auction ID tracker. Skip 0 to keep the starting index empty
        currentAuctionID++;

        /// @dev Calculate the timestamp after which this auction can be settled
        uint256 auctionEndTime = time + AUCTION_DURATION;

        /// @dev Update this auction's data in the mapping / struct
        Auction storage auction = auctionInfo[currentAuctionID];
        auction.asset = asset;
        auction.amountToAuction = amount;
        // auction.totalSuppliedTokens --> 0 (default)
        auction.endTime = auctionEndTime;
        // auction.claimedAssets --> 0 (default)

        // Interactions
        /// @dev Emit event that a new auction has started
        emit AuctionStarted(currentAuctionID, asset, auctionEndTime, amount);
    }

    // Supply the accumulated token to the auction of a specific asset
    function buyIntoAuction(uint256 _auctionID) external {}

    /// @notice Settle an active auction
    /// @dev Increase the total claimable balance
    /// @dev Update the last auction ID for the selected asset
    /// @dev Send the accumulated tokens to the recipient
    function settleAuction(uint256 _auctionID) public {
        //Checks
        /// @dev Cache parameters
        uint256 time = block.timestamp;
        Auction memory auction = auctionInfo[_auctionID];
        address asset = auction.asset;
        uint256 amount = auction.amountToAuction;
        uint256 suppliedTokens = auction.totalSuppliedToken;

        /// @dev Check if the auction is ongoing
        if (auction.endTime > time) revert ActiveAuction();

        /// @dev Prevent settlement if no PSM has been supplied
        if (suppliedTokens == 0) revert ZeroSupplied();

        // Effects
        /// @dev Update the asset related storage data
        assetClaimsTotal[asset] += amount;
        lastAuctionForAsset[asset] = _auctionID; // Because starting an auction settles the last, this sequence cannot be broken

        /// @dev Settle the auction
        isSettled[_auctionID] = true;

        // Interactions
        /// @dev Send the accumulated tokens to the recipient
        ACCUMULATED_TOKEN.safeTransfer(RECIPIENT, suppliedTokens);

        /// @dev Emit event that the auction has been settled
        emit AuctionSettled(_auctionID, asset, amount, suppliedTokens);
    }

    // Claim the assets from settled auctions (total claim balance of that asset)
    function claimAssets(address[] memory _asset) external {}

    ////////////////////////////////
    // Read Functions
    ////////////////////////////////
    // get the amount of assets received per 1 PSM in an auction considering newly added PSM (auctionPrice)
    function getAuctionPrice(address _asset, uint256 _addedPSM) public view returns (uint256 assetPerPSM) {
        // return 0 if inactive/passed auction
    }

    // Calculate the claimable amount of a specific asset by a user
    function getUserClaimBalance(address _user) public view returns (uint256 userClaim) {}

    /// @notice Calculate the amount of an Asset that is unassigned to auctions or claims
    function getAvailableAssets(address _asset) public view returns (uint256 available) {
        /// @dev Cache parameters
        uint256 balance;
        address asset = _asset;
        uint256 lastID = lastAuctionForAsset[asset];
        Auction memory auction = auctionInfo[lastID];
        uint256 totalReserved = auction.amountToAuction + assetClaimsTotal[asset];

        /// @dev Get balance of ETH or ERC20 token
        if (asset == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(asset).balanceOf(address(this));
        }

        /// @dev Calculate and return available token amount
        available = (balance > totalReserved) ? balance - totalReserved : 0;
    }

    ////////////////////////////////
    // ENABLE ETH
    ////////////////////////////////
    receive() external payable {}
    fallback() external payable {}
}
