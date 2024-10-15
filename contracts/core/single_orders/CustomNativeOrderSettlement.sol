// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../../tokens/IERC20Token.sol";
import "../../errors/LibRichErrorsV06.sol";
import "../../utils/LibMathV06.sol";
import "../../errors/LibNativeOrdersRichErrors.sol";
import "../../fixins/FixinCommon.sol";
import "../../interfaces/IStaking.sol";
import "../../libs/LibNativeOrdersStorage.sol";
import "../../interfaces/INativeOrderEvents.sol";
import "../../libs/LibSignature.sol";
import "../../libs/LibCustomOrder.sol";
import "./NativeOrdersCancellation.sol";
import "../../fees/CustomProtocolFees.sol";
import "./CustomOrderProtocolFees.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


abstract contract NativeOrdersSettlement is
    INativeOrdersEvents,
    NativeOrdersCancellation,
    CustomOrderProtocolFees,
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
        uint256 protocolFeeAmount;
        bool makerIsBuyer;  // Make sure this field is present
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
        address octagramAddress,
        IERC20 _feeToken,
        IStaking staking,
        CustomFeeCollectorController feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    )
        NativeOrdersCancellation(octagramAddress)
        CustomOrderProtocolFees(_feeToken, staking, feeCollectorController, makerFeePercentage, takerFeePercentage)
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
        
        // Determine the fee payer based on the order type or other logic
        address feePayer = _determineFeePayer(order, msg.sender);
        
        LibNativeOrder.refundExcessProtocolFeeToSender(
            FEE_TOKEN,
            feePayer,
            results.protocolFeePaid,
            results.protocolFeePaid
        );
        
        takerTokenFilledAmount = uint128(results.takerTokenFilledAmount);
        makerTokenFilledAmount = uint128(results.makerTokenFilledAmount);
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
        takerTokenFilledAmount = uint128(results.takerTokenFilledAmount);
        makerTokenFilledAmount = uint128(results.makerTokenFilledAmount);
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
                protocolFeeAmount: results.protocolFeePaid,
                makerIsBuyer: params.order.makerIsBuyer
            })
        );

        if (params.order.protocolFeeAmount > 0) {
            results.protocolFeePaid = uint128(
                LibMathV06.getPartialAmountFloor(
                    results.takerTokenFilledAmount,
                    params.order.takerAmount,
                    params.order.protocolFeeAmount
                )
            );
            _transferERC20TokensFrom(
                params.order.takerToken,
                params.taker,
                params.order.feeRecipient,
                uint256(results.protocolFeePaid)
            );
        }

        emit LimitOrderFilled(
            orderInfo.orderHash,
            params.order.maker,
            params.taker,
            params.order.feeRecipient,
            address(params.order.makerToken),
            address(params.order.takerToken),
            uint128(results.takerTokenFilledAmount),  // Cast to uint128
            uint128(results.makerTokenFilledAmount),  // Cast to uint128
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
        address feePayer = settleInfo.makerIsBuyer ? settleInfo.maker : settleInfo.payer;
        require(feeToken.transferFrom(feePayer, address(this), settleInfo.protocolFeeAmount), "Fee transfer failed");

        // Transfer tokens
        _transferERC20TokensFrom(settleInfo.takerToken, settleInfo.payer, settleInfo.maker, uint256(takerTokenFilledAmount));
        _transferERC20TokensFrom(settleInfo.makerToken, settleInfo.maker, settleInfo.recipient, uint256(makerTokenFilledAmount));

        return (takerTokenFilledAmount, makerTokenFilledAmount);
    }

    function registerAllowedOrderSigner(address signer, bool allowed) external {
        LibNativeOrdersStorage.Storage storage stor = LibNativeOrdersStorage.getStorage();
        stor.orderSignerRegistry[msg.sender][signer] = allowed;
        emit OrderSignerRegistered(msg.sender, signer, allowed);
    }

    function min(uint128 a, uint128 b) private pure returns (uint128) {
        return a < b ? a : b;
    }

    function _determineFeePayer(LibNativeOrder.LimitOrder memory order, address taker) internal pure returns (address) {
        return order.makerIsBuyer ? order.maker : taker;
    }
}
