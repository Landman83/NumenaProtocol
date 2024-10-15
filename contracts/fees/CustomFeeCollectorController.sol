// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../interfaces/IStaking.sol";
import "./CustomFeeCollector.sol";
import "./LibFeeCollector.sol";

contract CustomFeeCollectorController {
    bytes32 public immutable FEE_COLLECTOR_INIT_CODE_HASH;
    IERC20Token public immutable FEE_TOKEN;
    IStaking public immutable STAKING;

    constructor(IERC20Token feeToken, IStaking staking) {
        FEE_COLLECTOR_INIT_CODE_HASH = keccak256(type(CustomFeeCollector).creationCode);
        FEE_TOKEN = feeToken;
        STAKING = staking;
    }

    function prepareFeeCollectorToPayFees(bytes32 poolId) external returns (CustomFeeCollector feeCollector) {
        feeCollector = getFeeCollector(poolId);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(feeCollector)
        }
        if (codeSize == 0) {
            new CustomFeeCollector{salt: bytes32(poolId)}(FEE_TOKEN, STAKING, poolId);
        }
        return feeCollector;
    }

    function getFeeCollector(bytes32 poolId) public view returns (CustomFeeCollector feeCollector) {
        return
            CustomFeeCollector(LibFeeCollector.getFeeCollectorAddress(address(this), FEE_COLLECTOR_INIT_CODE_HASH, poolId));
    }
}