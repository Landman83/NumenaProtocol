// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibOwnableRichErrorsMatchedOrders {
    function OnlyOwnerError(address sender, address owner) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("OnlyOwnerError(address,address)")),
            sender,
            owner
        );
    }

    function TransferOwnerToZeroError() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("TransferOwnerToZeroError()")));
    }

    function MigrateCallFailedError(address target, bytes memory resultData) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("MigrateCallFailedError(address,bytes)")),
            target,
            resultData
        );
    }

    function UnauthorizedMatchedOrderOperatorError(address operator) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("UnauthorizedMatchedOrderOperatorError(address)")),
            operator
        );
    }
}