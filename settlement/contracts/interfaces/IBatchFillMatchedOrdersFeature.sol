// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../libs/LibMatchedOrder.sol";
import "../libs/LibSignature.sol";

/// @dev Feature for batch filling matched orders.
interface IBatchFillMatchedOrdersFeature {
    /// @dev Fills multiple matched orders.
    /// @param orders Array of matched orders.
    /// @param signatures Array of signatures corresponding to each order.
    /// @param fillAmounts Array of desired amounts to fill each order.
    /// @param revertIfIncomplete If true, reverts if this function fails to
    ///        fill the full fill amount for any individual order.
    /// @return cashTokenFilledAmounts Array of amounts filled, in cash token.
    /// @return securityTokenFilledAmounts Array of amounts filled, in security token.
    function batchFillMatchedOrders(
        LibMatchedOrder.MatchedOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures,
        uint128[] calldata fillAmounts,
        bool revertIfIncomplete
    ) external payable returns (uint128[] memory cashTokenFilledAmounts, uint128[] memory securityTokenFilledAmounts);
}