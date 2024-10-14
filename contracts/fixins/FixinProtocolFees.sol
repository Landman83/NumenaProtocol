// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IEtherToken.sol";
import "../fees/FeeCollector.sol";
import "../fees/FeeCollectorController.sol";
import "../fees/LibFeeCollector.sol";
import "../interfaces/IStaking.sol";

abstract contract FixinProtocolFees {
    uint32 public immutable PROTOCOL_FEE_MULTIPLIER;
    FeeCollectorController private immutable FEE_COLLECTOR_CONTROLLER;
    bytes32 private immutable FEE_COLLECTOR_INIT_CODE_HASH;
    IEtherToken private immutable WETH;
    IStaking private immutable STAKING;

    constructor(
        IEtherToken weth,
        IStaking staking,
        FeeCollectorController feeCollectorController,
        uint32 protocolFeeMultiplier
    ) {
        FEE_COLLECTOR_CONTROLLER = feeCollectorController;
        FEE_COLLECTOR_INIT_CODE_HASH = feeCollectorController.FEE_COLLECTOR_INIT_CODE_HASH();
        WETH = weth;
        STAKING = staking;
        PROTOCOL_FEE_MULTIPLIER = protocolFeeMultiplier;
    }

    function _collectProtocolFee(bytes32 poolId) internal returns (uint256 ethProtocolFeePaid) {
        uint256 protocolFeePaid = _getSingleProtocolFee();
        if (protocolFeePaid == 0) {
            return 0;
        }
        FeeCollector feeCollector = _getFeeCollector(poolId);
        (bool success, ) = address(feeCollector).call{value: protocolFeePaid}("");
        require(success, "FixinProtocolFees/ETHER_TRANSFER_FALIED");
        return protocolFeePaid;
    }

    function _transferFeesForPool(bytes32 poolId) internal {
        FeeCollector feeCollector = FEE_COLLECTOR_CONTROLLER.prepareFeeCollectorToPayFees(poolId);
        uint256 bal = WETH.balanceOf(address(feeCollector));
        if (bal > 1) {
            STAKING.payProtocolFee(address(feeCollector), address(feeCollector), bal - 1);
        }
    }

    function _getFeeCollector(bytes32 poolId) internal view returns (FeeCollector) {
        return
            FeeCollector(
                LibFeeCollector.getFeeCollectorAddress(
                    address(FEE_COLLECTOR_CONTROLLER),
                    FEE_COLLECTOR_INIT_CODE_HASH,
                    poolId
                )
            );
    }

    function _getSingleProtocolFee() internal view returns (uint256 protocolFeeAmount) {
        return uint256(PROTOCOL_FEE_MULTIPLIER) * tx.gasprice;
    }
}