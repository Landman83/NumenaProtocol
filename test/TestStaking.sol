// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/tokens/IERC20Token.sol";
import "../contracts/interfaces/IStaking.sol";

contract TestStaking is IStaking {
    mapping(address => bytes32) public poolForMaker;
    mapping(bytes32 => uint256) public balanceForPool;
    IERC20Token immutable feeToken;

    constructor(IERC20Token _feeToken) {
        feeToken = _feeToken;
    }

    function joinStakingPoolAsMaker(bytes32 poolId) external override {
        poolForMaker[msg.sender] = poolId;
    }

    function payProtocolFee(
        address payerAddress,
        address poolOperatorAddress,
        uint256 amount
    ) external override {
        require(feeToken.transferFrom(payerAddress, address(this), amount));
        balanceForPool[poolForMaker[poolOperatorAddress]] += amount;
    }

    // Implement other required functions from IStaking interface
    function createStakingPool(uint32 operatorShare, bool addOperatorAsMaker) external override returns (bytes32 poolId) {
        // Implement or leave empty for testing
    }

    function currentEpoch() external view override returns (uint256 epoch) {
        // Implement or return a dummy value
    }

    function currentEpochStartTimeInSeconds() external view override returns (uint256 startTime) {
        // Implement or return a dummy value
    }

    function epochDurationInSeconds() external view override returns (uint256 duration) {
        // Implement or return a dummy value
    }

    function getStakingPool(bytes32 poolId) external view override returns (Pool memory) {
        // Implement or return a dummy value
    }

    function getGlobalStakeByStatus(StakeStatus stakeStatus) external view override returns (StoredBalance memory balance) {
        // Implement or return a dummy value
    }

    function getOwnerStakeByStatus(
        address staker,
        StakeStatus stakeStatus
    ) external view override returns (StoredBalance memory balance) {
        // Implement or return a dummy value
    }

    function getTotalStakeDelegatedToPool(bytes32 poolId) external view override returns (StoredBalance memory balance) {
        // Implement or return a dummy value
    }

    function getStakeDelegatedToPoolByOwner(
        address staker,
        bytes32 poolId
    ) external view override returns (StoredBalance memory balance) {
        // Implement or return a dummy value
    }
}
