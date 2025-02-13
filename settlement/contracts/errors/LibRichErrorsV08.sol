// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibRichErrorsV08 {
    bytes4 internal constant STANDARD_ERROR_SELECTOR = 0x08c379a0;

    function StandardError(string memory message) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(STANDARD_ERROR_SELECTOR, bytes(message));
    }

    function rrevert(bytes memory errorData) internal pure {
        assembly {
            revert(add(errorData, 0x20), mload(errorData))
        }
    }
}
