// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/tokens/IEtherToken.sol";

contract TestStaking {
    mapping(address => bytes32) public poolForMaker;
    mapping(bytes32 => uint256) public balanceForPool;
    IEtherToken immutable weth;

    constructor(IEtherToken _weth) {
        weth = _weth;
    }

    function joinStakingPoolAsMaker(bytes32 poolId) external {
        poolForMaker[msg.sender] = poolId;
    }

    function payProtocolFee(address makerAddress, address payerAddress, uint256 amount) external payable {
        require(weth.transferFrom(payerAddress, address(this), amount));
        balanceForPool[poolForMaker[makerAddress]] += amount;
    }
}