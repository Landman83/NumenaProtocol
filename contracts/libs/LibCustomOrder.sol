// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../errors/LibRichErrorsV08.sol";
import "../utils/LibSafeMathV06.sol";
import "../errors/LibNativeOrdersRichErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint128 protocolFeeAmount;  // Added this field
        address maker;
        address taker;
        address sender;
        address feeRecipient;
        bytes32 pool;
        uint64 expiry;
        uint256 salt;
        bool makerIsBuyer;
    }

    struct OrderInfo {
        bytes32 orderHash;
        OrderStatus status;
        uint128 takerTokenFilledAmount;
    }

    uint256 private constant UINT_128_MASK = (1 << 128) - 1;
    uint256 private constant UINT_64_MASK = (1 << 64) - 1;
    uint256 private constant ADDRESS_MASK = (1 << 160) - 1;

    uint256 private constant _LIMIT_ORDER_TYPEHASH = 0xce918627cb55462ddbb85e73de69a8b322f2bc88f4507c52fcad6d4c33c29d49;

    function getLimitOrderStructHash(LimitOrder memory order) internal pure returns (bytes32 structHash) {
        assembly {
            let mem := mload(0x40)
            mstore(mem, _LIMIT_ORDER_TYPEHASH)
            mstore(add(mem, 0x20), and(ADDRESS_MASK, mload(order)))
            mstore(add(mem, 0x40), and(ADDRESS_MASK, mload(add(order, 0x20))))
            mstore(add(mem, 0x60), and(UINT_128_MASK, mload(add(order, 0x40))))
            mstore(add(mem, 0x80), and(UINT_128_MASK, mload(add(order, 0x60))))
            mstore(add(mem, 0xA0), and(UINT_128_MASK, mload(add(order, 0x80))))  // protocolFeeAmount
            mstore(add(mem, 0xC0), and(ADDRESS_MASK, mload(add(order, 0xA0))))
            mstore(add(mem, 0xE0), and(ADDRESS_MASK, mload(add(order, 0xC0))))
            mstore(add(mem, 0x100), and(ADDRESS_MASK, mload(add(order, 0xE0))))
            mstore(add(mem, 0x120), and(ADDRESS_MASK, mload(add(order, 0x100))))
            mstore(add(mem, 0x140), mload(add(order, 0x120)))
            mstore(add(mem, 0x160), and(UINT_64_MASK, mload(add(order, 0x140))))
            mstore(add(mem, 0x180), mload(add(order, 0x160)))
            mstore(add(mem, 0x1A0), mload(add(order, 0x180)))  // makerIsBuyer
            structHash := keccak256(mem, 0x1C0)
        }
    }

    function refundExcessProtocolFeeToSender(
        IERC20 feeToken,
        address payer,
        uint256 protocolFeePaid,
        uint256 protocolFeeAmount
    ) internal {
        if (protocolFeePaid > protocolFeeAmount) {
            uint256 refundAmount = protocolFeePaid - protocolFeeAmount;
            require(feeToken.transfer(payer, refundAmount), "Fee refund failed");
        }
    }

    
}
