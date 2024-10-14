// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../errors/LibRichErrorsV08.sol";
import "../utils/LibSafeMathV06.sol";
import "../errors/LibNativeOrdersRichErrors.sol";

library LibNativeOrder {
    using LibSafeMathV06 for uint256;
    using LibRichErrorsV08 for bytes;

    enum OrderStatus {
        INVALID,
        FILLABLE,
        FILLED,
        CANCELLED,
        EXPIRED
    }

    struct LimitOrder {
        IERC20Token makerToken;
        IERC20Token takerToken;
        uint128 makerAmount;
        uint128 takerAmount;
        uint128 takerTokenFeeAmount;
        address maker;
        address taker;
        address sender;
        address feeRecipient;
        bytes32 pool;
        uint64 expiry;
        uint256 salt;
    }

    struct RfqOrder {
        IERC20Token makerToken;
        IERC20Token takerToken;
        uint128 makerAmount;
        uint128 takerAmount;
        address maker;
        address taker;
        address txOrigin;
        bytes32 pool;
        uint64 expiry;
        uint256 salt;
    }

    struct OtcOrder {
        IERC20Token makerToken;
        IERC20Token takerToken;
        uint128 makerAmount;
        uint128 takerAmount;
        address maker;
        address taker;
        address txOrigin;
        uint256 expiryAndNonce;
    }

    struct OrderInfo {
        bytes32 orderHash;
        OrderStatus status;
        uint128 takerTokenFilledAmount;
    }

    struct OtcOrderInfo {
        bytes32 orderHash;
        OrderStatus status;
    }

    uint256 private constant UINT_128_MASK = (1 << 128) - 1;
    uint256 private constant UINT_64_MASK = (1 << 64) - 1;
    uint256 private constant ADDRESS_MASK = (1 << 160) - 1;

    uint256 private constant _LIMIT_ORDER_TYPEHASH = 0xce918627cb55462ddbb85e73de69a8b322f2bc88f4507c52fcad6d4c33c29d49;
    uint256 private constant _RFQ_ORDER_TYPEHASH = 0xe593d3fdfa8b60e5e17a1b2204662ecbe15c23f2084b9ad5bae40359540a7da9;
    uint256 private constant _OTC_ORDER_TYPEHASH = 0x2f754524de756ae72459efbe1ec88c19a745639821de528ac3fb88f9e65e35c8;

    function getLimitOrderStructHash(LimitOrder memory order) internal pure returns (bytes32 structHash) {
        assembly {
            let mem := mload(0x40)
            mstore(mem, _LIMIT_ORDER_TYPEHASH)
            mstore(add(mem, 0x20), and(ADDRESS_MASK, mload(order)))
            mstore(add(mem, 0x40), and(ADDRESS_MASK, mload(add(order, 0x20))))
            mstore(add(mem, 0x60), and(UINT_128_MASK, mload(add(order, 0x40))))
            mstore(add(mem, 0x80), and(UINT_128_MASK, mload(add(order, 0x60))))
            mstore(add(mem, 0xA0), and(UINT_128_MASK, mload(add(order, 0x80))))
            mstore(add(mem, 0xC0), and(ADDRESS_MASK, mload(add(order, 0xA0))))
            mstore(add(mem, 0xE0), and(ADDRESS_MASK, mload(add(order, 0xC0))))
            mstore(add(mem, 0x100), and(ADDRESS_MASK, mload(add(order, 0xE0))))
            mstore(add(mem, 0x120), and(ADDRESS_MASK, mload(add(order, 0x100))))
            mstore(add(mem, 0x140), mload(add(order, 0x120)))
            mstore(add(mem, 0x160), and(UINT_64_MASK, mload(add(order, 0x140))))
            mstore(add(mem, 0x180), mload(add(order, 0x160)))
            structHash := keccak256(mem, 0x1A0)
        }
    }

    function getRfqOrderStructHash(RfqOrder memory order) internal pure returns (bytes32 structHash) {
        assembly {
            let mem := mload(0x40)
            mstore(mem, _RFQ_ORDER_TYPEHASH)
            mstore(add(mem, 0x20), and(ADDRESS_MASK, mload(order)))
            mstore(add(mem, 0x40), and(ADDRESS_MASK, mload(add(order, 0x20))))
            mstore(add(mem, 0x60), and(UINT_128_MASK, mload(add(order, 0x40))))
            mstore(add(mem, 0x80), and(UINT_128_MASK, mload(add(order, 0x60))))
            mstore(add(mem, 0xA0), and(ADDRESS_MASK, mload(add(order, 0x80))))
            mstore(add(mem, 0xC0), and(ADDRESS_MASK, mload(add(order, 0xA0))))
            mstore(add(mem, 0xE0), and(ADDRESS_MASK, mload(add(order, 0xC0))))
            mstore(add(mem, 0x100), mload(add(order, 0xE0)))
            mstore(add(mem, 0x120), and(UINT_64_MASK, mload(add(order, 0x100))))
            mstore(add(mem, 0x140), mload(add(order, 0x120)))
            structHash := keccak256(mem, 0x160)
        }
    }

    function getOtcOrderStructHash(OtcOrder memory order) internal pure returns (bytes32 structHash) {
        assembly {
            let mem := mload(0x40)
            mstore(mem, _OTC_ORDER_TYPEHASH)
            mstore(add(mem, 0x20), and(ADDRESS_MASK, mload(order)))
            mstore(add(mem, 0x40), and(ADDRESS_MASK, mload(add(order, 0x20))))
            mstore(add(mem, 0x60), and(UINT_128_MASK, mload(add(order, 0x40))))
            mstore(add(mem, 0x80), and(UINT_128_MASK, mload(add(order, 0x60))))
            mstore(add(mem, 0xA0), and(ADDRESS_MASK, mload(add(order, 0x80))))
            mstore(add(mem, 0xC0), and(ADDRESS_MASK, mload(add(order, 0xA0))))
            mstore(add(mem, 0xE0), and(ADDRESS_MASK, mload(add(order, 0xC0))))
            mstore(add(mem, 0x100), mload(add(order, 0xE0)))
            structHash := keccak256(mem, 0x120)
        }
    }

    function refundExcessProtocolFeeToSender(uint256 ethProtocolFeePaid) internal {
        if (msg.value > ethProtocolFeePaid && msg.sender != address(this)) {
            uint256 refundAmount = msg.value - ethProtocolFeePaid;
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            if (!success) {
                revert LibNativeOrdersRichErrors.ProtocolFeeRefundFailed(msg.sender, refundAmount);
            }
        }
    }
}