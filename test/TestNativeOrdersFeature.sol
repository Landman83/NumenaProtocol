// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/core/single_orders/CustomOrdersFeature.sol"; // Import the new settlement contract to accomodate changes in fee handling
import "./TestFeeCollectorController.sol";

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
            feeToken,
            staking,
            CustomFeeCollectorController(address(new TestFeeCollectorController())),
            makerFeePercentage,
            takerFeePercentage
        )
    {}

    modifier onlySelf() override {
        _;
    }
}