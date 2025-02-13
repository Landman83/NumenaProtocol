// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibMathRichErrorsV08 {
    bytes internal constant DIVISION_BY_ZERO_ERROR = hex"a791837c";
    bytes4 internal constant ROUNDING_ERROR_SELECTOR = 0x339f3de2;

    function DivisionByZeroError() internal pure returns (bytes memory) {
        return DIVISION_BY_ZERO_ERROR;
    }

    function RoundingError(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ROUNDING_ERROR_SELECTOR, numerator, denominator, target);
    }
}
