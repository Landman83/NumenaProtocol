// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IEtherToken.sol";
import "../utils/AuthorizableV06.sol";
import "../interfaces/IStaking.sol";

contract FeeCollector is AuthorizableV06 {
    receive() external payable {}

    constructor() {
        _addAuthorizedAddress(msg.sender);
    }

    function initialize(IEtherToken weth, IStaking staking, bytes32 poolId) external onlyAuthorized {
        weth.approve(address(staking), type(uint256).max);
        staking.joinStakingPoolAsMaker(poolId);
    }

    function convertToWeth(IEtherToken weth) external onlyAuthorized {
        if (address(this).balance > 0) {
            weth.deposit{value: address(this).balance}();
        }
    }
}