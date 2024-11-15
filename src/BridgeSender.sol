// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IArbitrumBridge {
    function outboundTransferCustomRefund(
        address _token,
        address _refundTo,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes calldata _data
    ) external payable returns (bytes memory);
}

// THIS CONTRACT IS WORK IN PROGRESS AND REQUIRES TESTING

contract BridgeSender {
    // Address of the Arbitrum bridge contract on Ethereum
    address public constant ARBITRUM_ERC20_GATEWAY_L1 = 0xa3A7B6F88361F48403514059F1F16C8E78d60EeC;
    address public constant ARBITRUM_GATEWAY_ROUTER_L1 = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef;

    // Address of the token contract on Ethereum
    address public immutable L1_tokenAddress; // 0x1330918030fB1032e1245FE2E2F499f02B916e19

    // Address of the token contract on Arbitrum
    address public immutable L2_tokenAddress; // 0xDf539Ae47B7F09F58Ea5f9d0b44ACcDd312B9330

    // Address of the recipient of the tokens on Arbitrum
    address public immutable L2_recipient; // 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33 -> treasury

    constructor(address _L1_tokenAddress, address _L2_tokenAddress, address _L2_recipient) {
        L1_tokenAddress = _L1_tokenAddress;
        L2_tokenAddress = _L2_tokenAddress;
        L2_recipient = _L2_recipient;
    }

    function sendTokensToL2(uint256 _maxGasL2, uint256 _gasPriceBidL2) external {
        // Checks

        // Effects
        IERC20 token = IERC20(L1_tokenAddress);
        uint256 balance = token.balanceOf(address(this));

        // create & encode the calldata
        bytes memory extraData;
        uint256 maxSubmissionCost = _maxGasL2 * _gasPriceBidL2;
        bytes memory packedData = abi.encode(maxSubmissionCost, extraData);

        // Interactions
        token.approve(ARBITRUM_ERC20_GATEWAY_L1, balance);

        // Call the deposit function on the Arbitrum bridge contract
        (bool success, bytes memory data) = ARBITRUM_GATEWAY_ROUTER_L1.call(
            abi.encodeWithSelector(
                IArbitrumBridge(ARBITRUM_GATEWAY_ROUTER_L1).outboundTransferCustomRefund.selector,
                L1_tokenAddress,
                msg.sender,
                L2_recipient,
                balance,
                _maxGasL2, // 60 mio
                _gasPriceBidL2, // 100k - 1 mio
                packedData
            )
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "Deposit failed");
    }
}
