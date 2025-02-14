// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../tokens/IERC20Token.sol";
import "../utils/AuthorizableV08.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/BuybackAndBurn.sol";

contract CustomFeeCollector is AuthorizableV08 {
    IERC20Token public immutable FEE_TOKEN;
    IStaking public immutable STAKING;
    BuybackAndBurn public immutable BUYBACK;
    bytes32 public immutable POOL_ID;
    
    // Configure fee split (in basis points)
    uint256 public constant BUYBACK_SHARE = 10000; // 20% to buyback
    uint256 public constant STAKING_SHARE = 0; // 80% to staking

    event FeesCollected(uint256 amount);

    constructor(
        IERC20Token feeToken,
        IStaking staking,
        BuybackAndBurn buyback,
        bytes32 poolId
    ) {
        FEE_TOKEN = feeToken;
        STAKING = staking;
        BUYBACK = buyback;
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
            // Split fees between buyback and staking
            uint256 buybackAmount = (balance * BUYBACK_SHARE) / 10000;
            uint256 stakingAmount = (balance * STAKING_SHARE) / 10000;

            // Transfer to buyback
            if (buybackAmount > 0) {
                FEE_TOKEN.approve(address(BUYBACK), buybackAmount);
                BUYBACK.receiveFees();
            }

            // Transfer to staking
            if (stakingAmount > 0) {
                FEE_TOKEN.approve(address(STAKING), stakingAmount);
                STAKING.payProtocolFee(address(this), address(this), stakingAmount);
            }
        }
    }

    function withdrawFees(address recipient, uint256 amount) external onlyAuthorized {
        require(FEE_TOKEN.transfer(recipient, amount), "Fee withdrawal failed");
    }
}
