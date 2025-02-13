// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/libs/LibCustomOrder.sol";

contract TestLibNativeOrder {
    function getLimitOrderStructHash(
        LibNativeOrder.LimitOrder calldata order
    ) external pure returns (bytes32 structHash) {
        return LibNativeOrder.getLimitOrderStructHash(order);
    }
}