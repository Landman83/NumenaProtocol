// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/core/single_orders/CustomOrdersFeature.sol";
import "./TestFeeCollectorController.sol";
import "../contracts/tokens/IERC20Token.sol";
import "../contracts/interfaces/IStaking.sol";

abstract contract TestNativeOrdersFeature is NativeOrdersFeature {
    constructor(
        address octagramAddress,
        IERC20 _feeToken,
        IStaking staking,
        CustomFeeCollectorController _feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    )
        NativeOrdersFeature(
            octagramAddress,
            _feeToken,
            staking,
            _feeCollectorController,
            makerFeePercentage,
            takerFeePercentage
        )
    {}

    modifier onlySelf() override {
        _;
    }
}
