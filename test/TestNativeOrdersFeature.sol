// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/core/single_orders/NativeOrdersFeature.sol";
import "./TestFeeCollectorController.sol";

contract TestNativeOrdersFeature is NativeOrdersFeature {
    constructor(
        address zeroExAddress,
        IEtherToken weth,
        IStaking staking,
        FeeCollectorController _feeCollectorController,
        uint32 protocolFeeMultiplier
    )
        NativeOrdersFeature(
            zeroExAddress,
            weth,
            staking,
            FeeCollectorController(address(new TestFeeCollectorController())),
            protocolFeeMultiplier
        )
    {}

    modifier onlySelf() override {
        _;
    }
}