// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

contract TestFeeRecipient {
    bytes4 private constant SUCCESS = this.receiveZeroExFeeCallback.selector;
    bytes4 private constant FAILURE = 0xdeadbeef;
    uint256 private constant TRIGGER_REVERT = 333;
    uint256 private constant TRIGGER_FAILURE = 666;

    event FeeReceived(address tokenAddress, uint256 amount);

    receive() external payable {}

    function receiveZeroExFeeCallback(
        address tokenAddress,
        uint256 amount,
        bytes calldata
    ) external returns (bytes4 success) {
        emit FeeReceived(tokenAddress, amount);
        if (amount == TRIGGER_REVERT) {
            revert("TestFeeRecipient::receiveZeroExFeeCallback/REVERT");
        } else if (amount == TRIGGER_FAILURE) {
            return FAILURE;
        } else {
            return SUCCESS;
        }
    }
}