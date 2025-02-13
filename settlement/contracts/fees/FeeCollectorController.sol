// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IEtherToken.sol";
import "../interfaces/IStaking.sol";
import "./FeeCollector.sol";
import "./LibFeeCollector.sol";

contract FeeCollectorController {
    bytes32 public immutable FEE_COLLECTOR_INIT_CODE_HASH;
    IEtherToken private immutable WETH;
    IStaking private immutable STAKING;

    constructor(IEtherToken weth, IStaking staking) {
        FEE_COLLECTOR_INIT_CODE_HASH = keccak256(type(FeeCollector).creationCode);
        WETH = weth;
        STAKING = staking;
    }

    function prepareFeeCollectorToPayFees(bytes32 poolId) external returns (FeeCollector feeCollector) {
        feeCollector = getFeeCollector(poolId);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(feeCollector)
        }
        if (codeSize == 0) {
            new FeeCollector{salt: bytes32(poolId)}();
            feeCollector.initialize(WETH, STAKING, poolId);
        }
        if (address(feeCollector).balance > 1) {
            feeCollector.convertToWeth(WETH);
        }
        return feeCollector;
    }

    function getFeeCollector(bytes32 poolId) public view returns (FeeCollector feeCollector) {
        return
            FeeCollector(LibFeeCollector.getFeeCollectorAddress(address(this), FEE_COLLECTOR_INIT_CODE_HASH, poolId));
    }
}