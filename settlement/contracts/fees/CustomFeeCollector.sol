// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../utils/AuthorizableV08.sol";
import "../interfaces/IStaking.sol";

contract CustomFeeCollector is AuthorizableV08 {
    IERC20Token public immutable FEE_TOKEN;
    IStaking public immutable STAKING;
    bytes32 public immutable POOL_ID;

    event FeesCollected(uint256 amount);

    constructor(IERC20Token feeToken, IStaking staking, bytes32 poolId) {
        FEE_TOKEN = feeToken;
        STAKING = staking;
        POOL_ID = poolId;
        _addAuthorizedAddress(msg.sender);
    }

    function collectFees(address payer, uint256 amount) external onlyAuthorized {
        require(FEE_TOKEN.transferFrom(payer, address(this), amount), "Fee transfer failed");
        emit FeesCollected(amount);
    }

    function transferFeesToStaking() external onlyAuthorized {
        uint256 balance = FEE_TOKEN.balanceOf(address(this));
        if (balance > 0) {
            FEE_TOKEN.approve(address(STAKING), balance);
            STAKING.payProtocolFee(address(this), address(this), balance);
        }
    }

    function withdrawFees(address recipient, uint256 amount) external onlyAuthorized {
        require(FEE_TOKEN.transfer(recipient, amount), "Fee withdrawal failed");
    }
}
