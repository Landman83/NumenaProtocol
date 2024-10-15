// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../../tokens/IERC20Token.sol";
import "../../errors/LibRichErrorsV06.sol";
import "../../utils/LibMathV06.sol";
import "../../errors/LibNativeOrdersRichErrors.sol";
import "../../fixins/FixinCommon.sol";
import "../../libs/LibNativeOrdersStorage.sol";
import "../../interfaces/IStaking.sol";
import "../../interfaces/INativeOrderEvents.sol";
import "../../libs/LibSignature.sol";
import "../../libs/LibNativeOrder.sol";
import "./NativeOrdersCancellation.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../fees/CustomProtocolFees.sol";

abstract contract NativeOrdersSettlement is
    INativeOrdersEvents,
    NativeOrdersCancellation,
    FixinProtocolFees,
    FixinCommon
{
    using LibRichErrorsV08 for bytes;

    struct SettleOrderInfo {
        bytes32 orderHash;
        address maker;
        address payer;
        address recipient;
        IERC20Token makerToken;
        IERC20Token takerToken;
        uint128 makerAmount;
        uint128 takerAmount;
        uint128 takerTokenFillAmount;
        uint128 takerTokenFilledAmount;
        uint256 protocolFeeAmount;  // Changed from makerFeePaid and takerFeePaid
    }

    struct FillLimitOrderPrivateParams {
        LibNativeOrder.LimitOrder order;
        LibSignature.Signature signature;
        uint128 takerTokenFillAmount;
        address taker;
        address sender;
    }

    struct FillNativeOrderResults {
        uint256 makerTokenFilledAmount;
        uint256 takerTokenFilledAmount;
        uint256 protocolFeePaid;  // Changed from makerFeePaid and takerFeePaid
    }

    IERC20 public immutable feeToken;

    constructor(
        address zeroExAddress,
        IERC20 _feeToken,
        IStaking staking,
        FeeCollectorController feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    )
        NativeOrdersCancellation(zeroExAddress)
        FixinProtocolFees(_feeToken, staking, feeCollectorController, makerFeePercentage, takerFeePercentage)
    {
        feeToken = _feeToken;
    }

    function fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory signature,
        uint128 takerTokenFillAmount
    ) public payable returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        FillNativeOrderResults memory results = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams({
                order: order,
                signature: signature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                sender: msg.sender
            })
        );
        LibNativeOrder.refundExcessProtocolFeeToSender(results.protocolFeePaid);
        (takerTokenFilledAmount, makerTokenFilledAmount) = (
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount
        );
    }

    function _fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory signature,
        uint128 takerTokenFillAmount,
        address taker,
        address sender
    ) public payable virtual onlySelf returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        FillNativeOrderResults memory results = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams(order, signature, takerTokenFillAmount, taker, sender)
        );
        (takerTokenFilledAmount, makerTokenFilledAmount) = (
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount
        );
    }

    function _fillLimitOrderPrivate(
        FillLimitOrderPrivateParams memory params
    ) private returns (FillNativeOrderResults memory results) {
        LibNativeOrder.OrderInfo memory orderInfo = getLimitOrderInfo(params.order);

        if (orderInfo.status != LibNativeOrder.OrderStatus.FILLABLE) {
            revert LibNativeOrdersRichErrors.OrderNotFillableError(orderInfo.orderHash, uint8(orderInfo.status));
        }

        if (params.order.taker != address(0) && params.order.taker != params.taker) {
            revert LibNativeOrdersRichErrors
                .OrderNotFillableByTakerError(orderInfo.orderHash, params.taker, params.order.taker);
        }

        if (params.order.sender != address(0) && params.order.sender != params.sender) {
            revert LibNativeOrdersRichErrors
                .OrderNotFillableBySenderError(orderInfo.orderHash, params.sender, params.order.sender);
        }

        {
            address signer = LibSignature.getSignerOfHash(orderInfo.orderHash, params.signature);
            if (signer != params.order.maker && !isValidOrderSigner(params.order.maker, signer)) {
                revert LibNativeOrdersRichErrors
                    .OrderNotSignedByMakerError(orderInfo.orderHash, signer, params.order.maker);
            }
        }

        results.protocolFeePaid = params.order.protocolFeeAmount;

        (results.takerTokenFilledAmount, results.makerTokenFilledAmount) = _settleOrder(
            SettleOrderInfo({
                orderHash: orderInfo.orderHash,
                maker: params.order.maker,
                payer: params.taker,
                recipient: params.taker,
                makerToken: IERC20Token(params.order.makerToken),
                takerToken: IERC20Token(params.order.takerToken),
                makerAmount: params.order.makerAmount,
                takerAmount: params.order.takerAmount,
                takerTokenFillAmount: params.takerTokenFillAmount,
                takerTokenFilledAmount: orderInfo.takerTokenFilledAmount,
                protocolFeeAmount: results.protocolFeePaid
            })
        );

        if (params.order.takerTokenFeeAmount > 0) {
            results.takerTokenFeeFilledAmount = uint128(
                LibMathV06.getPartialAmountFloor(
                    results.takerTokenFilledAmount,
                    params.order.takerAmount,
                    params.order.takerTokenFeeAmount
                )
            );
            _transferERC20TokensFrom(
                params.order.takerToken,
                params.taker,
                params.order.feeRecipient,
                uint256(results.takerTokenFeeFilledAmount)
            );
        }

        emit LimitOrderFilled(
            orderInfo.orderHash,
            params.order.maker,
            params.taker,
            params.order.feeRecipient,
            address(params.order.makerToken),
            address(params.order.takerToken),
            results.takerTokenFilledAmount,
            results.makerTokenFilledAmount,
            results.takerTokenFeeFilledAmount,
            results.protocolFeePaid,
            params.order.pool
        );
    }

    function _settleOrder(
        SettleOrderInfo memory settleInfo
    ) private returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        takerTokenFilledAmount = min(
            settleInfo.takerTokenFillAmount,
            settleInfo.takerAmount - settleInfo.takerTokenFilledAmount
        );
        makerTokenFilledAmount = uint128(
            LibMathV06.getPartialAmountFloor(
                uint256(takerTokenFilledAmount),
                uint256(settleInfo.takerAmount),
                uint256(settleInfo.makerAmount)
            )
        );

        if (takerTokenFilledAmount == 0 || makerTokenFilledAmount == 0) {
            return (0, 0);
        }

        LibNativeOrdersStorage.getStorage().orderHashToTakerTokenFilledAmount[settleInfo.orderHash] = settleInfo
            .takerTokenFilledAmount + takerTokenFilledAmount;

        // Collect fee
        address feePayer = settleInfo.maker;  // Default to maker paying fee
        if (!LibNativeOrder.isOrderMakerIsBuyer(settleInfo.orderHash)) {
            feePayer = settleInfo.payer;  // If maker is not buyer, payer (taker) pays fee
        }
        require(feeToken.transferFrom(feePayer, address(this), settleInfo.protocolFeeAmount), "Fee transfer failed");

        // Transfer tokens
        _transferERC20TokensFrom(settleInfo.takerToken, settleInfo.payer, settleInfo.maker, uint256(takerTokenFilledAmount));
        _transferERC20TokensFrom(settleInfo.makerToken, settleInfo.maker, settleInfo.recipient, uint256(makerTokenFilledAmount));
    }

    function registerAllowedOrderSigner(address signer, bool allowed) external {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();
        stor.orderSignerRegistry[msg.sender][signer] = allowed;
        emit OrderSignerRegistered(msg.sender, signer, allowed);
    }

    function min(uint128 a, uint128 b) private pure returns (uint128) {
        return a < b ? a : b;
    }

    function collectProtocolFee(address from, uint256 amount) internal {
        require(feeToken.transferFrom(from, address(this), amount), "Fee transfer failed");
    }
}
