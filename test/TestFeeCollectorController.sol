// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/fees/CustomFeeCollectorController.sol";
import "../contracts/tokens/IERC20Token.sol";
import "../contracts/interfaces/IStaking.sol";

contract TestFeeCollectorController is CustomFeeCollectorController {
    constructor(
        IERC20Token feeToken,
        IStaking staking
    ) CustomFeeCollectorController(feeToken, staking) {}
}
