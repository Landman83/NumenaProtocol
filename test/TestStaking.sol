// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/interfaces/IStaking.sol";
import "../contracts/tokens/IERC20Token.sol";

contract TestStaking is IStaking {
    IERC20Token public immutable feeToken;

    constructor(IERC20Token _feeToken) {
        feeToken = _feeToken;
    }

    function createStakingPool(uint32 operatorShare, bool addOperatorAsMaker) external returns (bytes32 poolId) {
        return bytes32(0);
    }

    function currentEpoch() external view returns (uint256 epoch) {
        return 0;
    }

    function currentEpochStartTimeInSeconds() external view returns (uint256 startTime) {
        return 0;
    }

    function epochDurationInSeconds() external view returns (uint256 duration) {
        return 0;
    }

    function getStakingPool(bytes32 poolId) external view returns (Pool memory) {
        return Pool(address(0), 0);
    }

    function getGlobalStakeByStatus(StakeStatus stakeStatus) external view returns (StoredBalance memory balance) {
        return StoredBalance(0, 0, 0);
    }

    function getOwnerStakeByStatus(address staker, StakeStatus stakeStatus) 
        external view returns (StoredBalance memory balance) 
    {
        return StoredBalance(0, 0, 0);
    }

    function getTotalStakeDelegatedToPool(bytes32 poolId) external view returns (StoredBalance memory balance) {
        return StoredBalance(0, 0, 0);
    }

    function getStakeDelegatedToPoolByOwner(address staker, bytes32 poolId) 
        external view returns (StoredBalance memory balance) 
    {
        return StoredBalance(0, 0, 0);
    }

    function joinStakingPoolAsMaker(bytes32 poolId) external {
        // No-op for testing
    }

    function payProtocolFee(address payerAddress, address poolOperatorAddress, uint256 amount) external {
        // No-op for testing
    }
}
