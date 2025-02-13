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
import "../../fixins/FixinERC3643TokenSpender.sol";


abstract contract NativeOrdersSettlement is
    INativeOrdersEvents,
    NativeOrdersCancellation,
    CustomOrderProtocolFees,
    FixinCommon,
    FixinERC3643TokenSpender
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
        LibSignature.Signature makerSignature;  // Changed to separate maker signature
        LibSignature.Signature takerSignature;  // Added taker signature
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

    struct OrderSignature {
        LibSignature.SignatureType signatureType;
        uint8 maker_v;
        bytes32 maker_r;
        bytes32 maker_s;
        uint8 taker_v;
        bytes32 taker_r;
        bytes32 taker_s;
    }

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
        OrderSignature memory signatures,  // Changed from signature to signatures
        uint128 takerTokenFillAmount
    ) public payable virtual returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        // Convert OrderSignature to LibSignature.Signature
        LibSignature.Signature memory makerSig = LibSignature.Signature({
            signatureType: signatures.signatureType,
            v: signatures.maker_v,
            r: signatures.maker_r,
            s: signatures.maker_s
        });

        LibSignature.Signature memory takerSig = LibSignature.Signature({
            signatureType: signatures.signatureType,
            v: signatures.taker_v,
            r: signatures.taker_r,
            s: signatures.taker_s
        });

        FillNativeOrderResults memory results = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams({
                order: order,
                makerSignature: makerSig,
                takerSignature: takerSig,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: msg.sender,
                sender: msg.sender
            })
        );
        
        takerTokenFilledAmount = uint128(results.takerTokenFilledAmount);
        makerTokenFilledAmount = uint128(results.makerTokenFilledAmount);
    }

    function _fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory makerSignature,  // Changed
        LibSignature.Signature memory takerSignature,  // Added
        uint128 takerTokenFillAmount,
        address taker,
        address sender
    ) public payable virtual onlySelf returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        FillNativeOrderResults memory results = _fillLimitOrderPrivate(
            FillLimitOrderPrivateParams({
                order: order,
                makerSignature: makerSignature,
                takerSignature: takerSignature,
                takerTokenFillAmount: takerTokenFillAmount,
                taker: taker,
                sender: sender
            })
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

        // Verify maker signature
        address makerSigner = LibSignature.getSignerOfHash(orderInfo.orderHash, params.makerSignature);
        if (makerSigner != params.order.maker && !isValidOrderSigner(params.order.maker, makerSigner)) {
            revert LibNativeOrdersRichErrors
                .OrderNotSignedByMakerError(orderInfo.orderHash, makerSigner, params.order.maker);
        }

        // Verify taker signature
        address takerSigner = LibSignature.getSignerOfHash(orderInfo.orderHash, params.takerSignature);
        if (takerSigner != params.taker) {
            revert LibNativeOrdersRichErrors.OrderNotSignedByTakerError(
                orderInfo.orderHash,
                takerSigner,
                params.taker
            );
        }

        if (params.order.taker != address(0) && params.order.taker != params.taker) {
            revert LibNativeOrdersRichErrors
                .OrderNotFillableByTakerError(orderInfo.orderHash, params.taker, params.order.taker);
        }

        if (params.order.sender != address(0) && params.order.sender != params.sender) {
            revert LibNativeOrdersRichErrors
                .OrderNotFillableBySenderError(orderInfo.orderHash, params.sender, params.order.sender);
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
            revert LibNativeOrdersRichErrors.InsufficientFillAmount(
                settleInfo.orderHash, 
                takerTokenFilledAmount, 
                makerTokenFilledAmount
            );
        }

        LibNativeOrdersStorage.getStorage().orderHashToTakerTokenFilledAmount[settleInfo.orderHash] = settleInfo
            .takerTokenFilledAmount + takerTokenFilledAmount;

        // Modified transfer logic to handle both ERC20 and ERC3643 tokens
        if (_isERC3643(address(settleInfo.takerToken))) {
            _transferERC3643TokensFrom(
                address(settleInfo.takerToken),
                settleInfo.payer,
                settleInfo.maker,
                uint256(takerTokenFilledAmount)
            );
        } else {
            _transferERC20TokensFrom(
                settleInfo.takerToken,
                settleInfo.payer,
                settleInfo.maker,
                uint256(takerTokenFilledAmount)
            );
        }

        if (_isERC3643(address(settleInfo.makerToken))) {
            _transferERC3643TokensFrom(
                address(settleInfo.makerToken),
                settleInfo.maker,
                settleInfo.recipient,
                uint256(makerTokenFilledAmount)
            );
        } else {
            _transferERC20TokensFrom(
                settleInfo.makerToken,
                settleInfo.maker,
                settleInfo.recipient,
                uint256(makerTokenFilledAmount)
            );
        }

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

    function _verifyOrderSignature(
        bytes32 orderHash,
        address maker,
        address taker,
        OrderSignature memory signature
    ) internal pure {  // Changed from 'internal' to 'internal pure'
        // Verify maker signature
        LibSignature.Signature memory makerSig = LibSignature.Signature({
            signatureType: signature.signatureType,
            v: signature.maker_v,
            r: signature.maker_r,
            s: signature.maker_s
        });
        
        // Verify taker signature
        LibSignature.Signature memory takerSig = LibSignature.Signature({
            signatureType: signature.signatureType,
            v: signature.taker_v,
            r: signature.taker_r,
            s: signature.taker_s
        });

        // Verify both signatures
        require(
            LibSignature.getSignerOfHash(orderHash, makerSig) == maker,
            "Invalid maker signature"
        );
        require(
            LibSignature.getSignerOfHash(orderHash, takerSig) == taker,
            "Invalid taker signature"
        );
    }
}