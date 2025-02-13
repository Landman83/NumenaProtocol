// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibAuthorizableRichErrorsV08 {
    bytes4 internal constant AUTHORIZED_ADDRESS_MISMATCH_ERROR_SELECTOR = 0x140a84db;
    bytes4 internal constant INDEX_OUT_OF_BOUNDS_ERROR_SELECTOR = 0xe9f83771;
    bytes4 internal constant SENDER_NOT_AUTHORIZED_ERROR_SELECTOR = 0xb65a25b9;
    bytes4 internal constant TARGET_ALREADY_AUTHORIZED_ERROR_SELECTOR = 0xde16f1a0;
    bytes4 internal constant TARGET_NOT_AUTHORIZED_ERROR_SELECTOR = 0xeb5108a2;
    bytes internal constant ZERO_CANT_BE_AUTHORIZED_ERROR_BYTES = hex"57654fe4";

    function AuthorizedAddressMismatchError(address authorized, address target) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(AUTHORIZED_ADDRESS_MISMATCH_ERROR_SELECTOR, authorized, target);
    }

    function IndexOutOfBoundsError(uint256 index, uint256 length) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(INDEX_OUT_OF_BOUNDS_ERROR_SELECTOR, index, length);
    }

    function SenderNotAuthorizedError(address sender) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SENDER_NOT_AUTHORIZED_ERROR_SELECTOR, sender);
    }

    function TargetAlreadyAuthorizedError(address target) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(TARGET_ALREADY_AUTHORIZED_ERROR_SELECTOR, target);
    }

    function TargetNotAuthorizedError(address target) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(TARGET_NOT_AUTHORIZED_ERROR_SELECTOR, target);
    }

    function ZeroCantBeAuthorizedError() internal pure returns (bytes memory) {
        return ZERO_CANT_BE_AUTHORIZED_ERROR_BYTES;
    }
}
