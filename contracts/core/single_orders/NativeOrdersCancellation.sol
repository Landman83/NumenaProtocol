// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../../tokens/IERC20Token.sol";
import "../../errors/LibRichErrorsV08.sol";
import "../../errors/LibNativeOrdersRichErrors.sol";
import "../../libs/LibNativeOrdersStorage.sol";
import "../../interfaces/INativeOrderEvents.sol";
import "../../libs/LibSignature.sol";
import "../../libs/LibNativeOrder.sol";
import "./NativeOrdersInfo.sol";

abstract contract NativeOrdersCancellation is INativeOrdersEvents, NativeOrdersInfo {
    using LibRichErrorsV08 for bytes;

    uint256 private constant HIGH_BIT = 1 << 255;

    constructor(address zeroExAddress) NativeOrdersInfo(zeroExAddress) {}

    function cancelLimitOrder(LibNativeOrder.LimitOrder memory order) public {
        bytes32 orderHash = getLimitOrderHash(order);
        if (msg.sender != order.maker && !isValidOrderSigner(order.maker, msg.sender)) {
            LibNativeOrdersRichErrors.OnlyOrderMakerAllowed(orderHash, msg.sender, order.maker).rrevert();
        }
        _cancelOrderHash(orderHash, order.maker);
    }

    function cancelRfqOrder(LibNativeOrder.RfqOrder memory order) public {
        bytes32 orderHash = getRfqOrderHash(order);
        if (msg.sender != order.maker && !isValidOrderSigner(order.maker, msg.sender)) {
            LibNativeOrdersRichErrors.OnlyOrderMakerAllowed(orderHash, msg.sender, order.maker).rrevert();
        }
        _cancelOrderHash(orderHash, order.maker);
    }

    function batchCancelLimitOrders(LibNativeOrder.LimitOrder[] memory orders) public {
        for (uint256 i = 0; i < orders.length; ++i) {
            cancelLimitOrder(orders[i]);
        }
    }

    function batchCancelRfqOrders(LibNativeOrder.RfqOrder[] memory orders) public {
        for (uint256 i = 0; i < orders.length; ++i) {
            cancelRfqOrder(orders[i]);
        }
    }

    function cancelPairLimitOrders(IERC20Token makerToken, IERC20Token takerToken, uint256 minValidSalt) public {
        _cancelPairLimitOrders(msg.sender, makerToken, takerToken, minValidSalt);
    }

    function cancelPairLimitOrdersWithSigner(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) public {
        if (!isValidOrderSigner(maker, msg.sender)) {
            LibNativeOrdersRichErrors.InvalidSignerError(maker, msg.sender).rrevert();
        }

        _cancelPairLimitOrders(maker, makerToken, takerToken, minValidSalt);
    }

    function batchCancelPairLimitOrders(
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairLimitOrders(msg.sender, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    function batchCancelPairLimitOrdersWithSigner(
        address maker,
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        if (!isValidOrderSigner(maker, msg.sender)) {
            LibNativeOrdersRichErrors.InvalidSignerError(maker, msg.sender).rrevert();
        }

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairLimitOrders(maker, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    function cancelPairRfqOrders(IERC20Token makerToken, IERC20Token takerToken, uint256 minValidSalt) public {
        _cancelPairRfqOrders(msg.sender, makerToken, takerToken, minValidSalt);
    }

    function cancelPairRfqOrdersWithSigner(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) public {
        if (!isValidOrderSigner(maker, msg.sender)) {
            LibNativeOrdersRichErrors.InvalidSignerError(maker, msg.sender).rrevert();
        }

        _cancelPairRfqOrders(maker, makerToken, takerToken, minValidSalt);
    }

    function batchCancelPairRfqOrders(
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairRfqOrders(msg.sender, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    function batchCancelPairRfqOrdersWithSigner(
        address maker,
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) public {
        require(
            makerTokens.length == takerTokens.length && makerTokens.length == minValidSalts.length,
            "NativeOrdersFeature/MISMATCHED_PAIR_ORDERS_ARRAY_LENGTHS"
        );

        if (!isValidOrderSigner(maker, msg.sender)) {
            LibNativeOrdersRichErrors.InvalidSignerError(maker, msg.sender).rrevert();
        }

        for (uint256 i = 0; i < makerTokens.length; ++i) {
            _cancelPairRfqOrders(maker, makerTokens[i], takerTokens[i], minValidSalts[i]);
        }
    }

    function _cancelOrderHash(bytes32 orderHash, address maker) private {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();
        stor.orderHashToTakerTokenFilledAmount[orderHash] |= HIGH_BIT;

        emit OrderCancelled(orderHash, maker);
    }

    function _cancelPairRfqOrders(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) private {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();

        uint256 oldMinValidSalt = stor.rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][
            address(makerToken)
        ][address(takerToken)];

        if (oldMinValidSalt > minValidSalt) {
            LibNativeOrdersRichErrors.CancelSaltTooLowError(minValidSalt, oldMinValidSalt).rrevert();
        }

        stor.rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][address(makerToken)][
            address(takerToken)
        ] = minValidSalt;

        emit PairCancelledRfqOrders(maker, address(makerToken), address(takerToken), minValidSalt);
    }

    function _cancelPairLimitOrders(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) private {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();

        uint256 oldMinValidSalt = stor.limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][
            address(makerToken)
        ][address(takerToken)];

        if (oldMinValidSalt > minValidSalt) {
            LibNativeOrdersRichErrors.CancelSaltTooLowError(minValidSalt, oldMinValidSalt).rrevert();
        }

        stor.limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[maker][address(makerToken)][
            address(takerToken)
        ] = minValidSalt;

        emit PairCancelledLimitOrders(maker, address(makerToken), address(takerToken), minValidSalt);
    }
}