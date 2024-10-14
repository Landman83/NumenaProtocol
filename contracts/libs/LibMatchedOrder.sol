// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

/*
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library LibNativeOrder {
    enum OrderStatus {
        INVALID,
        FILLABLE,
        FILLED,
        CANCELLED,
        EXPIRED
    }

    struct MatchedOrder {
        address cashToken;
        address securityToken;
        uint128 cashAmount;
        uint128 securityAmount;
        address buyer;
        address seller;
        address sender;
        bytes32 pool;
        uint64 expiry;
        uint256 salt;
    }

    struct OrderInfo {
        bytes32 orderHash;
        OrderStatus status;
        uint128 securityTokenFilledAmount;
    }

    error ProtocolFeeRefundFailed(address sender, uint256 amount);

    uint256 private constant UINT_128_MASK = type(uint128).max;
    uint256 private constant UINT_64_MASK = type(uint64).max;
    uint256 private constant ADDRESS_MASK = type(uint160).max;

    uint256 private constant _MATCHED_ORDER_TYPEHASH = 0x12345678; // This needs to be recalculated based on the new struct

    function getMatchedOrderStructHash(MatchedOrder memory order) internal pure returns (bytes32 structHash) {
        assembly {
            let mem := mload(0x40)
            mstore(mem, _MATCHED_ORDER_TYPEHASH)
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

    function refundExcessProtocolFeeToSender(uint256 ethProtocolFeePaid) internal {
        if (msg.value > ethProtocolFeePaid && msg.sender != address(this)) {
            uint256 refundAmount = msg.value - ethProtocolFeePaid;
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            if (!success) {
                revert ProtocolFeeRefundFailed(msg.sender, refundAmount);
            }
        }
    }
}

*/