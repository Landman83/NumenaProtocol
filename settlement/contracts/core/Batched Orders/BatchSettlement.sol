// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@0x/contracts-utils/contracts/src/errors/LibRichErrors.sol";
import "../errors/MatchedOrdersRichErrors.sol";
import "../fixins/FixinCommon.sol";
import "../fixins/FixinEIP712.sol";
import "../migrations/LibMigrate.sol";
import "./interfaces/IFeature.sol";
import "./interfaces/IBatchFillNativeOrdersFeature.sol";
import "./interfaces/IMatchedOrdersFeature.sol";
import "./libs/LibMatchedOrder.sol";
import "./libs/LibSignature.sol";

contract BatchSettlement is IFeature, IBatchFillMatchedOrdersFeature, FixinCommon, FixinEIP712 {
    using LibRichErrors for bytes;

    string public constant override FEATURE_NAME = "AdaptiveBatchFillLimit";
    uint256 public immutable override FEATURE_VERSION = _encodeVersion(1, 5, 0);

    uint256 public constant MAX_BATCH_SIZE = 1000;
    uint256 public constant MIN_BATCH_SIZE = 10;
    uint256 public currentBatchSize;
    uint256 public lastUpdateTimestamp;
    uint256 public orderQueueSize;

    struct BatchMetadata {
        bytes32 merkleRoot;
        uint256 timestamp;
        uint256 gasPrice;
    }

    struct MatchedOrder {
        LibNativeOrder.LimitOrder order;
        LibSignature.Signature signature;
        uint128 fillAmount;
        address cashToken;
        address securityToken;
        address buyer;
        address seller;
    }

    mapping(bytes32 => BatchMetadata) public processedBatches;
    mapping(bytes32 => uint128) public filledAmounts;

    event BatchProcessed(bytes32 indexed batchId, uint256 ordersProcessed, uint256 gasUsed);
    event OrderFilled(bytes32 indexed orderHash, uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);

    constructor(address zeroExAddress) FixinEIP712(zeroExAddress) {
        currentBatchSize = 100; // Starting batch size
        lastUpdateTimestamp = block.timestamp;
    }

    function migrate() external returns (bytes4 success) {
        _registerFeatureFunction(this.processBatch.selector);
        return LibMigrate.MIGRATE_SUCCESS;
    }

    function processBatch(
        bytes32 merkleRoot,
        bytes[] calldata orderData,
        bytes32[][] calldata merkleProofs
    ) external payable {
        require(orderData.length <= currentBatchSize, "Batch size exceeded");
        
        bytes32 batchId = keccak256(abi.encode(merkleRoot, block.timestamp));
        uint256 gasStart = gasleft();

        uint256 protocolFee = INativeOrdersFeature(address(this)).getProtocolFeeMultiplier() * tx.gasprice;
        uint256 ethProtocolFeePaid = 0;

        uint128[] memory cashTokenFilledAmounts = new uint128[](orderData.length);
        uint128[] memory securityTokenFilledAmounts = new uint128[](orderData.length);

        for (uint256 i = 0; i < orderData.length; i++) {
            bytes32 leaf = keccak256(orderData[i]);
            require(MerkleProof.verify(merkleProofs[i], merkleRoot, leaf), "Invalid Merkle proof");
            
            MatchedOrder memory matchedOrder = abi.decode(orderData[i], (MatchedOrder));
            bytes32 orderHash = LibNativeOrder.getLimitOrderHash(matchedOrder.order);
            
            // Check if order has already been filled
            require(filledAmounts[orderHash] == 0, "Order already filled");

            (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = 
                INativeOrdersFeature(address(this))._fillLimitOrder(
                    matchedOrder.order,
                    matchedOrder.signature,
                    matchedOrder.fillAmount,
                    matchedOrder.buyer,
                    matchedOrder.seller
                );

            // Update filled amounts
            filledAmounts[orderHash] = takerTokenFilledAmount;

            // Determine which amount corresponds to cash and security
            if (matchedOrder.order.takerToken == matchedOrder.cashToken) {
                cashTokenFilledAmounts[i] = takerTokenFilledAmount;
                securityTokenFilledAmounts[i] = makerTokenFilledAmount;
            } else {
                cashTokenFilledAmounts[i] = makerTokenFilledAmount;
                securityTokenFilledAmounts[i] = takerTokenFilledAmount;
            }

            ethProtocolFeePaid += protocolFee;

            // Transfer tokens
            _safeTransferFrom(matchedOrder.cashToken, matchedOrder.buyer, matchedOrder.seller, cashTokenFilledAmounts[i]);
            _safeTransferFrom(matchedOrder.securityToken, matchedOrder.seller, matchedOrder.buyer, securityTokenFilledAmounts[i]);

            emit OrderFilled(orderHash, takerTokenFilledAmount, makerTokenFilledAmount);
        }

        uint256 gasUsed = gasStart - gasleft();
        processedBatches[batchId] = BatchMetadata(merkleRoot, block.timestamp, tx.gasprice);
        emit BatchProcessed(batchId, orderData.length, gasUsed);

        updateBatchSize(gasUsed, orderData.length);
        updateOrderQueue(orderData.length);

        LibNativeOrder.refundExcessProtocolFeeToSender(ethProtocolFeePaid);
    }

    function updateBatchSize(uint256 gasUsed, uint256 ordersProcessed) internal {
        uint256 gasPerOrder = gasUsed / ordersProcessed;
        uint256 optimalOrdersPerBatch = (block.gaslimit * 2 / 3) / gasPerOrder; // Target 2/3 of block gas limit

        if (optimalOrdersPerBatch > currentBatchSize && currentBatchSize < MAX_BATCH_SIZE) {
            currentBatchSize = Math.min(currentBatchSize * 2, MAX_BATCH_SIZE);
        } else if (optimalOrdersPerBatch < currentBatchSize && currentBatchSize > MIN_BATCH_SIZE) {
            currentBatchSize = Math.max(currentBatchSize / 2, MIN_BATCH_SIZE);
        }

        lastUpdateTimestamp = block.timestamp;
    }

    function updateOrderQueue(uint256 processedOrders) internal {
        if (processedOrders >= orderQueueSize) {
            orderQueueSize = 0;
        } else {
            orderQueueSize -= processedOrders;
        }
    }

    function addToOrderQueue(uint256 newOrders) external {
        orderQueueSize += newOrders;
        if (orderQueueSize > currentBatchSize * 10) {
            currentBatchSize = Math.min(currentBatchSize * 2, MAX_BATCH_SIZE);
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            LibNativeOrdersRichErrors.TransferFailedError(token, from, to, amount).rrevert();
        }
    }

    // Helper function to get the current batch size
    function getCurrentBatchSize() external view returns (uint256) {
        return currentBatchSize;
    }

    // Helper function to get the current order queue size
    function getOrderQueueSize() external view returns (uint256) {
        return orderQueueSize;
    }
}