// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibCommonRichErrorsMatchedOrders {
    function OnlyCallableBySelfError(address sender) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("OnlyCallableBySelfError(address)")),
            sender
        );
    }

    function IllegalReentrancyError(bytes4 selector, uint256 reentrancyFlags) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("IllegalReentrancyError(bytes4,uint256)")),
            selector,
            reentrancyFlags
        );
    }

    function InvalidMatchedOrderError(bytes32 orderHash) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("InvalidMatchedOrderError(bytes32)")),
            orderHash
        );
    }
}