// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@0x/contracts-erc20/src/IERC20Token.sol";
import "@0x/contracts-utils/contracts/src/v06/LibSafeMathV06.sol";
import "@0x/contracts-utils/contracts/src/v06/LibMathV06.sol";
import "../../fixins/FixinEIP712.sol";
import "../../fixins/FixinTokenSpender.sol";
import "../../libs/LibNativeOrdersStorage.sol";
import "../../libs/LibSignature.sol";
import "../../libs/LibNativeOrder.sol";

abstract contract NativeOrdersInfo is FixinEIP712, FixinTokenSpender {
    using LibSafeMathV06 for uint256;
    using LibRichErrorsV06 for bytes;

    struct GetActualFillableTakerTokenAmountParams {
        address maker;
        IERC20Token makerToken;
        uint128 orderMakerAmount;
        uint128 orderTakerAmount;
        LibNativeOrder.OrderInfo orderInfo;
    }

    uint256 private constant HIGH_BIT = 1 << 255;

    constructor(address zeroExAddress) FixinEIP712(zeroExAddress) {}

    function getLimitOrderInfo(
        LibNativeOrder.LimitOrder memory order
    ) public view returns (LibNativeOrder.OrderInfo memory orderInfo) {
        orderInfo.orderHash = getLimitOrderHash(order);
        uint256 minValidSalt = LibNativeOrdersStorage
            .getStorage()
            .limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[order.maker][address(order.makerToken)][
                address(order.takerToken)
            ];
        _populateCommonOrderInfoFields(orderInfo, order.takerAmount, order.expiry, order.salt, minValidSalt);
    }

    function getRfqOrderInfo(
        LibNativeOrder.RfqOrder memory order
    ) public view returns (LibNativeOrder.OrderInfo memory orderInfo) {
        orderInfo.orderHash = getRfqOrderHash(order);
        uint256 minValidSalt = LibNativeOrdersStorage
            .getStorage()
            .rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt[order.maker][address(order.makerToken)][
                address(order.takerToken)
            ];
        _populateCommonOrderInfoFields(orderInfo, order.takerAmount, order.expiry, order.salt, minValidSalt);

        if (order.txOrigin == address(0)) {
            orderInfo.status = LibNativeOrder.OrderStatus.INVALID;
        }
    }

    function getLimitOrderHash(LibNativeOrder.LimitOrder memory order) public view returns (bytes32 orderHash) {
        return _getEIP712Hash(LibNativeOrder.getLimitOrderStructHash(order));
    }

    function getRfqOrderHash(LibNativeOrder.RfqOrder memory order) public view returns (bytes32 orderHash) {
        return _getEIP712Hash(LibNativeOrder.getRfqOrderStructHash(order));
    }

    function getLimitOrderRelevantState(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature calldata signature
    )
        public
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        )
    {
        orderInfo = getLimitOrderInfo(order);
        actualFillableTakerTokenAmount = _getActualFillableTakerTokenAmount(
            GetActualFillableTakerTokenAmountParams({
                maker: order.maker,
                makerToken: order.makerToken,
                orderMakerAmount: order.makerAmount,
                orderTakerAmount: order.takerAmount,
                orderInfo: orderInfo
            })
        );
        address signerOfHash = LibSignature.getSignerOfHash(orderInfo.orderHash, signature);
        isSignatureValid = (order.maker == signerOfHash) || isValidOrderSigner(order.maker, signerOfHash);
    }

    function getRfqOrderRelevantState(
        LibNativeOrder.RfqOrder memory order,
        LibSignature.Signature memory signature
    )
        public
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        )
    {
        orderInfo = getRfqOrderInfo(order);
        actualFillableTakerTokenAmount = _getActualFillableTakerTokenAmount(
            GetActualFillableTakerTokenAmountParams({
                maker: order.maker,
                makerToken: order.makerToken,
                orderMakerAmount: order.makerAmount,
                orderTakerAmount: order.takerAmount,
                orderInfo: orderInfo
            })
        );
        address signerOfHash = LibSignature.getSignerOfHash(orderInfo.orderHash, signature);
        isSignatureValid = (order.maker == signerOfHash) || isValidOrderSigner(order.maker, signerOfHash);
    }

    function batchGetLimitOrderRelevantStates(
        LibNativeOrder.LimitOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo[] memory orderInfos,
            uint128[] memory actualFillableTakerTokenAmounts,
            bool[] memory isSignatureValids
        )
    {
        require(orders.length == signatures.length, "NativeOrdersFeature/MISMATCHED_ARRAY_LENGTHS");
        orderInfos = new LibNativeOrder.OrderInfo[](orders.length);
        actualFillableTakerTokenAmounts = new uint128[](orders.length);
        isSignatureValids = new bool[](orders.length);
        for (uint256 i = 0; i < orders.length; ++i) {
            try this.getLimitOrderRelevantState(orders[i], signatures[i]) returns (
                LibNativeOrder.OrderInfo memory orderInfo,
                uint128 actualFillableTakerTokenAmount,
                bool isSignatureValid
            ) {
                orderInfos[i] = orderInfo;
                actualFillableTakerTokenAmounts[i] = actualFillableTakerTokenAmount;
                isSignatureValids[i] = isSignatureValid;
            } catch {}
        }
    }

    function batchGetRfqOrderRelevantStates(
        LibNativeOrder.RfqOrder[] calldata orders,
        LibSignature.Signature[] calldata signatures
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo[] memory orderInfos,
            uint128[] memory actualFillableTakerTokenAmounts,
            bool[] memory isSignatureValids
        )
    {
        require(orders.length == signatures.length, "NativeOrdersFeature/MISMATCHED_ARRAY_LENGTHS");
        orderInfos = new LibNativeOrder.OrderInfo[](orders.length);
        actualFillableTakerTokenAmounts = new uint128[](orders.length);
        isSignatureValids = new bool[](orders.length);
        for (uint256 i = 0; i < orders.length; ++i) {
            try this.getRfqOrderRelevantState(orders[i], signatures[i]) returns (
                LibNativeOrder.OrderInfo memory orderInfo,
                uint128 actualFillableTakerTokenAmount,
                bool isSignatureValid
            ) {
                orderInfos[i] = orderInfo;
                actualFillableTakerTokenAmounts[i] = actualFillableTakerTokenAmount;
                isSignatureValids[i] = isSignatureValid;
            } catch {}
        }
    }

    function _populateCommonOrderInfoFields(
        LibNativeOrder.OrderInfo memory orderInfo,
        uint128 takerAmount,
        uint64 expiry,
        uint256 salt,
        uint256 minValidSalt
    ) private view {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();

        {
            uint256 rawTakerTokenFilledAmount = stor.orderHashToTakerTokenFilledAmount[orderInfo.orderHash];
            orderInfo.takerTokenFilledAmount = uint128(rawTakerTokenFilledAmount);
            if (orderInfo.takerTokenFilledAmount >= takerAmount) {
                orderInfo.status = LibNativeOrder.OrderStatus.FILLED;
                return;
            }
            if (rawTakerTokenFilledAmount & HIGH_BIT != 0) {
                orderInfo.status = LibNativeOrder.OrderStatus.CANCELLED;
                return;
            }
        }

        if (expiry <= uint64(block.timestamp)) {
            orderInfo.status = LibNativeOrder.OrderStatus.EXPIRED;
            return;
        }

        if (minValidSalt > salt) {
            orderInfo.status = LibNativeOrder.OrderStatus.CANCELLED;
            return;
        }
        orderInfo.status = LibNativeOrder.OrderStatus.FILLABLE;
    }

    function _getActualFillableTakerTokenAmount(
        GetActualFillableTakerTokenAmountParams memory params
    ) private view returns (uint128 actualFillableTakerTokenAmount) {
        if (params.orderMakerAmount == 0 || params.orderTakerAmount == 0) {
            return 0;
        }
        if (params.orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            return 0;
        }

        uint256 fillableMakerTokenAmount = LibMathV06.getPartialAmountFloor(
            uint256(params.orderTakerAmount - params.orderInfo.takerTokenFilledAmount),
            uint256(params.orderTakerAmount),
            uint256(params.orderMakerAmount)
        );
        fillableMakerTokenAmount = LibSafeMathV06.min256(
            fillableMakerTokenAmount,
            _getSpendableERC20BalanceOf(params.makerToken, params.maker)
        );
        return
            LibMathV06
                .getPartialAmountCeil(
                    fillableMakerTokenAmount,
                    uint256(params.orderMakerAmount),
                    uint256(params.orderTakerAmount)
                )
                .safeDowncastToUint128();
    }

    function isValidOrderSigner(address maker, address signer) public view returns (bool isValid) {
        return LibNativeOrdersStorage.getStorage().orderSignerRegistry[maker][signer];
    }
}