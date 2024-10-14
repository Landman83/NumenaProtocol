// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

interface IStaking {
    enum StakeStatus {
        UNDELEGATED,
        DELEGATED
    }

    struct StoredBalance {
        uint64 currentEpoch;
        uint96 currentEpochBalance;
        uint96 nextEpochBalance;
    }

    struct Pool {
        address operator;
        uint32 operatorShare;
    }

    function createStakingPool(uint32 operatorShare, bool addOperatorAsMaker) external returns (bytes32 poolId);

    function currentEpoch() external view returns (uint256 epoch);

    function currentEpochStartTimeInSeconds() external view returns (uint256 startTime);

    function epochDurationInSeconds() external view returns (uint256 duration);

    function getStakingPool(bytes32 poolId) external view returns (Pool memory);

    function getGlobalStakeByStatus(StakeStatus stakeStatus) external view returns (StoredBalance memory balance);

    function getOwnerStakeByStatus(
        address staker,
        StakeStatus stakeStatus
    ) external view returns (StoredBalance memory balance);

    function getTotalStakeDelegatedToPool(bytes32 poolId) external view returns (StoredBalance memory balance);

    function getStakeDelegatedToPoolByOwner(
        address staker,
        bytes32 poolId
    ) external view returns (StoredBalance memory balance);
}