// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/fixins/FixinProtocolFees.sol";

contract TestFixinProtocolFees is FixinProtocolFees {
    constructor(
        IEtherToken weth,
        IStaking staking,
        FeeCollectorController feeCollectorController,
        uint32 protocolFeeMultiplier
    ) FixinProtocolFees(weth, staking, feeCollectorController, protocolFeeMultiplier) {}

    function collectProtocolFee(bytes32 poolId) external payable {
        _collectProtocolFee(poolId);
    }

    function transferFeesForPool(bytes32 poolId) external {
        _transferFeesForPool(poolId);
    }

    function getFeeCollector(bytes32 poolId) external view returns (FeeCollector) {
        return _getFeeCollector(poolId);
    }

    function getSingleProtocolFee() external view returns (uint256 protocolFeeAmount) {
        return _getSingleProtocolFee();
    }
}