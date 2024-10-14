// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./errors/LibRichErrorsV08.sol";
import "./errors/LibMathRichErrorsV08.sol";
import "./errors/LibSafeMathRichErrorsV08.sol";

library LibMathV08 {
    function max256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max128(uint128 a, uint128 b) internal pure returns (uint128) {
        return a >= b ? a : b;
    }

    function min128(uint128 a, uint128 b) internal pure returns (uint128) {
        return a < b ? a : b;
    }

    function safeDowncastToUint128(uint256 a) internal pure returns (uint128) {
        if (a > type(uint128).max) {
            LibRichErrorsV08.rrevert(
                LibSafeMathRichErrorsV08.Uint256DowncastError(
                    LibSafeMathRichErrorsV08.DowncastErrorCodes.VALUE_TOO_LARGE_TO_DOWNCAST_TO_UINT128,
                    a
                )
            );
        }
        return uint128(a);
    }

    function safeGetPartialAmountFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        if (isRoundingErrorFloor(numerator, denominator, target)) {
            LibRichErrorsV08.rrevert(LibMathRichErrorsV08.RoundingError(numerator, denominator, target));
        }

        partialAmount = (numerator * target) / denominator;
        return partialAmount;
    }

    function safeGetPartialAmountCeil(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        if (isRoundingErrorCeil(numerator, denominator, target)) {
            LibRichErrorsV08.rrevert(LibMathRichErrorsV08.RoundingError(numerator, denominator, target));
        }

        partialAmount = (numerator * target + (denominator - 1)) / denominator;

        return partialAmount;
    }

    function getPartialAmountFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        partialAmount = (numerator * target) / denominator;
        return partialAmount;
    }

    function getPartialAmountCeil(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        partialAmount = (numerator * target + (denominator - 1)) / denominator;

        return partialAmount;
    }

    function isRoundingErrorFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (bool isError) {
        if (denominator == 0) {
            LibRichErrorsV08.rrevert(LibMathRichErrorsV08.DivisionByZeroError());
        }

        if (target == 0 || numerator == 0) {
            return false;
        }

        uint256 remainder = mulmod(target, numerator, denominator);
        isError = remainder * 1000 >= numerator * target;
        return isError;
    }

    function isRoundingErrorCeil(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (bool isError) {
        if (denominator == 0) {
            LibRichErrorsV08.rrevert(LibMathRichErrorsV08.DivisionByZeroError());
        }

        if (target == 0 || numerator == 0) {
            return false;
        }
        uint256 remainder = mulmod(target, numerator, denominator);
        remainder = denominator - (remainder % denominator);
        isError = remainder * 1000 >= numerator * target;
        return isError;
    }
}
