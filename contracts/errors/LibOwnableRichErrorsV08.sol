// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibOwnableRichErrorsV08 {
    bytes4 internal constant ONLY_OWNER_ERROR_SELECTOR = 0x1de45ad1;
    bytes internal constant TRANSFER_OWNER_TO_ZERO_ERROR_BYTES = hex"e69edc3e";

    function OnlyOwnerError(address sender, address owner) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ONLY_OWNER_ERROR_SELECTOR, sender, owner);
    }

    function TransferOwnerToZeroError() internal pure returns (bytes memory) {
        return TRANSFER_OWNER_TO_ZERO_ERROR_BYTES;
    }
}
