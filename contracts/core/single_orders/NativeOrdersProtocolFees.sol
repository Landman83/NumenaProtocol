pragma solidity ^0.8.26;

import "@0x/contracts-erc20/src/IEtherToken.sol";
import "@0x/contracts-utils/contracts/src/v06/errors/LibRichErrorsV06.sol";
import "@0x/contracts-utils/contracts/src/v06/LibSafeMathV06.sol";
import "../../fixins/FixinProtocolFees.sol";
import "../../errors/LibNativeOrdersRichErrors.sol";
import "../../interfaces/IStaking.sol";

abstract contract NativeOrdersProtocolFees is FixinProtocolFees {
    using LibSafeMathV06 for uint256;
    using LibRichErrorsV06 for bytes;

    constructor(
        IEtherToken weth,
        IStaking staking,
        FeeCollectorController feeCollectorController,
        uint32 protocolFeeMultiplier
    ) FixinProtocolFees(weth, staking, feeCollectorController, protocolFeeMultiplier) {}

    function transferProtocolFeesForPools(bytes32[] calldata poolIds) external {
        for (uint256 i = 0; i < poolIds.length; ++i) {
            _transferFeesForPool(poolIds[i]);
        }
    }

    function getProtocolFeeMultiplier() external view returns (uint32 multiplier) {
        return PROTOCOL_FEE_MULTIPLIER;
    }
}