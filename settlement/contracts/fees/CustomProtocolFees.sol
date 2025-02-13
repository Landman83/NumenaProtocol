// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../fees/CustomFeeCollector.sol";
import "../fees/CustomFeeCollectorController.sol";
import "../fees/LibFeeCollector.sol";
import "../interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract CustomProtocolFees {
    IERC20 public immutable FEE_TOKEN;
    IStaking private immutable STAKING;
    CustomFeeCollectorController private immutable FEE_COLLECTOR_CONTROLLER;
    bytes32 private immutable FEE_COLLECTOR_INIT_CODE_HASH;
    
    uint256 public makerFeePercentage;
    uint256 public takerFeePercentage;

    constructor(
        IERC20 feeToken,
        IStaking staking,
        CustomFeeCollectorController feeCollectorController,
        uint256 _makerFeePercentage,
        uint256 _takerFeePercentage
    ) {
        FEE_TOKEN = feeToken;
        STAKING = staking;
        FEE_COLLECTOR_CONTROLLER = feeCollectorController;
        FEE_COLLECTOR_INIT_CODE_HASH = feeCollectorController.FEE_COLLECTOR_INIT_CODE_HASH();
        makerFeePercentage = _makerFeePercentage;
        takerFeePercentage = _takerFeePercentage;
    }

    function _collectProtocolFee(
        bytes32 poolId,
        address payer,
        uint256 protocolFeeAmount
    ) internal returns (uint256 feePaid) {
        if (protocolFeeAmount == 0) {
            return 0;
        }

        CustomFeeCollector feeCollector = _getFeeCollector(poolId);
        require(FEE_TOKEN.transferFrom(payer, address(feeCollector), protocolFeeAmount), "FixinProtocolFees/FEE_TRANSFER_FAILED");

        return protocolFeeAmount;
    }

    function _transferFeesForPool(bytes32 poolId) internal {
        CustomFeeCollector feeCollector = FEE_COLLECTOR_CONTROLLER.prepareFeeCollectorToPayFees(poolId);
        uint256 bal = FEE_TOKEN.balanceOf(address(feeCollector));
        if (bal > 1) {
            FEE_TOKEN.approve(address(STAKING), bal - 1);
            STAKING.payProtocolFee(address(feeCollector), address(feeCollector), bal - 1);
        }
    }

    function _getFeeCollector(bytes32 poolId) internal view returns (CustomFeeCollector) {
        return
            CustomFeeCollector(
                LibFeeCollector.getFeeCollectorAddress(
                    address(FEE_COLLECTOR_CONTROLLER),
                    FEE_COLLECTOR_INIT_CODE_HASH,
                    poolId
                )
            );
    }

    function calculateProtocolFee(
        uint256 makerAmount,
        uint256 takerAmount
    ) internal view returns (uint256) {
        uint256 makerFee = (makerAmount * makerFeePercentage) / 10000;
        uint256 takerFee = (takerAmount * takerFeePercentage) / 10000;
        return makerFee + takerFee;
    }

    function _updateMakerFeePercentage(uint256 newPercentage) internal {
        makerFeePercentage = newPercentage;
    }

    function _updateTakerFeePercentage(uint256 newPercentage) internal {
        takerFeePercentage = newPercentage;
    }
}
