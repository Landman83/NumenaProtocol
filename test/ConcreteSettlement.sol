// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/core/single_orders/CustomNativeOrderSettlement.sol";
import "../contracts/interfaces/IStaking.sol";
import "../contracts/fees/CustomFeeCollectorController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConcreteNativeOrdersSettlement is NativeOrdersSettlement {
    constructor(
        address octagramAddress,
        IERC20 feeToken,
        IStaking staking,
        CustomFeeCollectorController feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    )
        NativeOrdersSettlement(
            octagramAddress,
            feeToken,
            staking,
            feeCollectorController,
            makerFeePercentage,
            takerFeePercentage
        )
    {}

    // Override fillLimitOrder to make it non-virtual
    function fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        OrderSignature memory signatures,
        uint128 takerTokenFillAmount
    ) public payable override returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        return super.fillLimitOrder(order, signatures, takerTokenFillAmount);
    }

    // Override _fillLimitOrder to make it non-virtual
    function _fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory makerSignature,
        LibSignature.Signature memory takerSignature,
        uint128 takerTokenFillAmount,
        address taker,
        address sender
    ) public payable override returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        return super._fillLimitOrder(order, makerSignature, takerSignature, takerTokenFillAmount, taker, sender);
    }
}
