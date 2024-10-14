// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@0x/contracts-utils/contracts/src/errors/LibRichErrors.sol";
import "../errors/MatchedOrdersRichErrors.sol";
import "../fixins/FixinCommon.sol";
import "../fixins/FixinEIP712.sol";
import "../migrations/LibMigrate.sol";
import "./interfaces/IFeature.sol";
import "./interfaces/IBatchFillMatchedOrdersFeature.sol";
import "./interfaces/IMatchedOrdersFeature.sol";
import "./libs/LibMatchedOrder.sol";
import "./libs/LibSignature.sol";

// consider adding feature whereby batching is used once a certain threshold is met so that scalability is increased but only as needed

/// @title BatchSettlement
/// @notice Core settlement contract for batch processing of matched orders
contract BatchSettlement is 
    Initializable, 
    OwnableUpgradeable, 
    PausableUpgradeable,
    IFeature, 
    IBatchFillMatchedOrdersFeature, 
    FixinCommon, 
    FixinEIP712 
{
    using LibRichErrors for bytes;

    string public constant override FEATURE_NAME = "BatchFillLimit";
    uint256 public immutable override FEATURE_VERSION = _encodeVersion(1, 6, 0);

    uint256 public constant MAX_BATCH_SIZE = 1000;
    uint256 public constant MIN_BATCH_SIZE = 1;
    uint256 public currentBatchSize;
    uint256 public lastUpdateTimestamp;
    uint256 public orderQueueSize;

    /// @dev Percentage of block gas limit to target (66.67%)
    uint256 private constant TARGET_BATCH_GAS_PERCENTAGE = 6667;
    uint256 private constant PERCENTAGE_DENOMINATOR = 10000;

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
    event BatchSizeUpdated(uint256 newBatchSize);
    event OrderQueueSizeChanged(uint256 newSize);

    error InvalidMerkleProof();
    error OrderAlreadyFilled();
    error TransferFailed();
    error UnauthorizedAccess();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address zeroExAddress) public initializer {
        __Ownable_init();
        __Pausable_init();
        FixinEIP712.__FixinEIP712_init(zeroExAddress);
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
    ) external payable whenNotPaused {
        if (orderData.length > currentBatchSize) revert("Batch size exceeded");
        
        bytes32 batchId = keccak256(abi.encode(merkleRoot, block.timestamp));
        uint256 gasStart = gasleft();

        uint256 protocolFee = INativeOrdersFeature(address(this)).getProtocolFeeMultiplier() * tx.gasprice;
        uint256 ethProtocolFeePaid = 0;

        uint128[] memory cashTokenFilledAmounts = new uint128[](orderData.length);
        uint128[] memory securityTokenFilledAmounts = new uint128[](orderData.length);

        for (uint256 i = 0; i < orderData.length; i++) {
            bytes32 leaf = keccak256(orderData[i]);
            if (!MerkleProof.verify(merkleProofs[i], merkleRoot, leaf)) revert InvalidMerkleProof();
            
            MatchedOrder memory matchedOrder = abi.decode(orderData[i], (MatchedOrder));
            bytes32 orderHash = LibNativeOrder.getLimitOrderHash(matchedOrder.order);
            
            if (filledAmounts[orderHash] != 0) revert OrderAlreadyFilled();

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
        unchecked {
            uint256 gasPerOrder = gasUsed / ordersProcessed;
            uint256 optimalOrdersPerBatch = (block.gaslimit * TARGET_BATCH_GAS_PERCENTAGE) / (gasPerOrder * PERCENTAGE_DENOMINATOR);

            uint256 newBatchSize = currentBatchSize;
            if (optimalOrdersPerBatch > currentBatchSize && currentBatchSize < MAX_BATCH_SIZE) {
                newBatchSize = MathUpgradeable.min(currentBatchSize * 2, MAX_BATCH_SIZE);
            } else if (optimalOrdersPerBatch < currentBatchSize && currentBatchSize > MIN_BATCH_SIZE) {
                newBatchSize = MathUpgradeable.max(currentBatchSize / 2, MIN_BATCH_SIZE);
            }

            if (newBatchSize != currentBatchSize) {
                currentBatchSize = newBatchSize;
                emit BatchSizeUpdated(newBatchSize);
            }

            lastUpdateTimestamp = block.timestamp;
        }
    }

    function updateOrderQueue(uint256 processedOrders) internal {
        unchecked {
            if (processedOrders >= orderQueueSize) {
                orderQueueSize = 0;
            } else {
                orderQueueSize -= processedOrders;
            }
        }
        emit OrderQueueSizeChanged(orderQueueSize);
    }

    function addToOrderQueue(uint256 newOrders) external onlyOwner {
        orderQueueSize += newOrders;
        if (orderQueueSize > currentBatchSize * 10) {
            currentBatchSize = MathUpgradeable.min(currentBatchSize * 2, MAX_BATCH_SIZE);
            emit BatchSizeUpdated(currentBatchSize);
        }
        emit OrderQueueSizeChanged(orderQueueSize);
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
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

    // Circuit breaker functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}