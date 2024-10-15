// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../../tokens/IERC20Token.sol";
import "../../errors/LibRichErrorsV08.sol";
import "../../utils/LibSafeMathV06.sol";
import "../../fees/CustomProtocolFees.sol";
import "../../errors/LibNativeOrdersRichErrors.sol";
import "../../interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract NativeOrdersProtocolFees is CustomProtocolFees {
    using LibSafeMathV06 for uint256;
    using LibRichErrorsV08 for bytes;

    constructor(
        IERC20 feeToken,
        IStaking staking,
        FeeCollectorController feeCollectorController,
        uint256 _makerFeePercentage,
        uint256 _takerFeePercentage
    ) CustomProtocolFees(feeToken, staking, feeCollectorController, _makerFeePercentage, _takerFeePercentage) {}

    function transferProtocolFeesForPools(bytes32[] calldata poolIds) external {
        for (uint256 i = 0; i < poolIds.length; ++i) {
            _transferFeesForPool(poolIds[i]);
        }
    }

    function getProtocolFee(uint256 makerAmount, uint256 takerAmount) public view returns (uint256) {
        return calculateProtocolFee(
            makerAmount,
            takerAmount,
            makerFeePercentage,
            takerFeePercentage
        );
    }
}
