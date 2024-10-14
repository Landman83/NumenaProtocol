// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@0x/contracts-utils/contracts/src/errors/LibRichErrors.sol";
import "../errors/MatchedOrdersRichErrors.sol";
import "../fixins/FixinCommon.sol";
import "../fixins/FixinEIP712.sol";
import "../migrations/LibMigrate.sol";
import "./interfaces/IFeature.sol";
import "./interfaces/IBatchFillMatchedOrdersFeature.sol";
import "./libs/LibNativeOrder.sol";
import "./libs/LibSignature.sol";

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
    uint256 public immutable override FEATURE_VERSION = _encodeVersion(1, 7, 0);

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

    error InvalidMerkleProof();
    error OrderAlreadyFilled();
    error TransferFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address zeroExAddress) public initializer {
        __Ownable_init();
        __Pausable_init();
        FixinEIP712.__FixinEIP712_init(zeroExAddress);
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
        bytes32 batchId = keccak256(abi.encode(merkleRoot, block.timestamp));
        uint256 gasStart = gasleft();

        uint256 protocolFee = INativeOrdersFeature(address(this)).getProtocolFeeMultiplier() * tx.gasprice;
        uint256 ethProtocolFeePaid = 0;

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

            filledAmounts[orderHash] = takerTokenFilledAmount;

            ethProtocolFeePaid += protocolFee;

            _safeTransferFrom(matchedOrder.cashToken, matchedOrder.buyer, matchedOrder.seller, 
                matchedOrder.order.takerToken == matchedOrder.cashToken ? takerTokenFilledAmount : makerTokenFilledAmount);
            _safeTransferFrom(matchedOrder.securityToken, matchedOrder.seller, matchedOrder.buyer, 
                matchedOrder.order.takerToken == matchedOrder.cashToken ? makerTokenFilledAmount : takerTokenFilledAmount);

            emit OrderFilled(orderHash, takerTokenFilledAmount, makerTokenFilledAmount);
        }

        uint256 gasUsed = gasStart - gasleft();
        processedBatches[batchId] = BatchMetadata(merkleRoot, block.timestamp, tx.gasprice);
        emit BatchProcessed(batchId, orderData.length, gasUsed);

        LibNativeOrder.refundExcessProtocolFeeToSender(ethProtocolFeePaid);
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

    // Circuit breaker functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}