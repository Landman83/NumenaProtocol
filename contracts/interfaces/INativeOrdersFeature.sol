// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@0x/contracts-erc20/src/IERC20Token.sol";
import "../libs/LibSignature.sol";
import "../libs/LibNativeOrder.sol";
import "./INativeOrderEvents.sol";

interface INativeOrdersFeature is INativeOrdersEvents {
    function transferProtocolFeesForPools(bytes32[] calldata poolIds) external;

    function fillLimitOrder(
        LibNativeOrder.LimitOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) external payable returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);

    function fillRfqOrder(
        LibNativeOrder.RfqOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) external returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);

    function fillOrKillLimitOrder(
        LibNativeOrder.LimitOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) external payable returns (uint128 makerTokenFilledAmount);

    function fillOrKillRfqOrder(
        LibNativeOrder.RfqOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount
    ) external returns (uint128 makerTokenFilledAmount);

    function _fillLimitOrder(
        LibNativeOrder.LimitOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount,
        address taker,
        address sender
    ) external payable returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);

    function _fillRfqOrder(
        LibNativeOrder.RfqOrder calldata order,
        LibSignature.Signature calldata signature,
        uint128 takerTokenFillAmount,
        address taker,
        bool useSelfBalance,
        address recipient
    ) external returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);

    function cancelLimitOrder(LibNativeOrder.LimitOrder calldata order) external;

    function cancelRfqOrder(LibNativeOrder.RfqOrder calldata order) external;

    function registerAllowedRfqOrigins(address[] memory origins, bool allowed) external;

    function batchCancelLimitOrders(LibNativeOrder.LimitOrder[] calldata orders) external;

    function batchCancelRfqOrders(LibNativeOrder.RfqOrder[] calldata orders) external;

    function cancelPairLimitOrders(IERC20Token makerToken, IERC20Token takerToken, uint256 minValidSalt) external;

    function cancelPairLimitOrdersWithSigner(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) external;

    function batchCancelPairLimitOrders(
        IERC20Token[] calldata makerTokens,
        IERC20Token[] calldata takerTokens,
        uint256[] calldata minValidSalts
    ) external;

    function batchCancelPairLimitOrdersWithSigner(
        address maker,
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) external;

    function cancelPairRfqOrders(IERC20Token makerToken, IERC20Token takerToken, uint256 minValidSalt) external;

    function cancelPairRfqOrdersWithSigner(
        address maker,
        IERC20Token makerToken,
        IERC20Token takerToken,
        uint256 minValidSalt
    ) external;

    function batchCancelPairRfqOrders(
        IERC20Token[] calldata makerTokens,
        IERC20Token[] calldata takerTokens,
        uint256[] calldata minValidSalts
    ) external;

    function batchCancelPairRfqOrdersWithSigner(
        address maker,
        IERC20Token[] memory makerTokens,
        IERC20Token[] memory takerTokens,
        uint256[] memory minValidSalts
    ) external;

    function getLimitOrderInfo(
        LibNativeOrder.LimitOrder calldata order
    ) external view returns (LibNativeOrder.OrderInfo memory orderInfo);

    function getRfqOrderInfo(
        LibNativeOrder.RfqOrder calldata order
    ) external view returns (LibNativeOrder.OrderInfo memory orderInfo);

    function getLimitOrderHash(LibNativeOrder.LimitOrder calldata order) external view returns (bytes32 orderHash);

    function getRfqOrderHash(LibNativeOrder.RfqOrder calldata order) external view returns (bytes32 orderHash);

    function getProtocolFeeMultiplier() external view returns (uint32 multiplier);

    function getLimitOrderRelevantState(
        LibNativeOrder.LimitOrder calldata order,
        LibSignature.Signature calldata signature
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        );

    function getRfqOrderRelevantState(
        LibNativeOrder.RfqOrder calldata order,
        LibSignature.Signature calldata signature
    )
        external
        view
        returns (
            LibNativeOrder.OrderInfo memory orderInfo,
            uint128 actualFillableTakerTokenAmount,
            bool isSignatureValid
        );

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
        );

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
        );

    function registerAllowedOrderSigner(address signer, bool allowed) external;

    function isValidOrderSigner(address maker, address signer) external view returns (bool isAllowed);
}