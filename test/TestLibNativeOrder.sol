// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/libs/LibNativeOrder.sol";

contract TestLibNativeOrder {
    function getLimitOrderStructHash(
        LibNativeOrder.LimitOrder calldata order
    ) external pure returns (bytes32 structHash) {
        return LibNativeOrder.getLimitOrderStructHash(order);
    }

    function getRfqOrderStructHash(LibNativeOrder.RfqOrder calldata order) external pure returns (bytes32 structHash) {
        return LibNativeOrder.getRfqOrderStructHash(order);
    }
}