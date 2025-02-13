// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./LibSafeMathV06.sol";
import "../errors/LibRichErrorsV08.sol";
import "../errors/LibMathRichErrorsV08.sol";

library LibMathV06 {
    using LibSafeMathV06 for uint256;

    function safeGetPartialAmountFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        if (isRoundingErrorFloor(numerator, denominator, target)) {
            LibRichErrorsV08.rrevert(LibMathRichErrorsV08.RoundingError(numerator, denominator, target));
        }

        partialAmount = numerator.safeMul(target).safeDiv(denominator);
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

        partialAmount = numerator.safeMul(target).safeAdd(denominator.safeSub(1)).safeDiv(denominator);

        return partialAmount;
    }

    function getPartialAmountFloor(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        partialAmount = numerator.safeMul(target).safeDiv(denominator);
        return partialAmount;
    }

    function getPartialAmountCeil(
        uint256 numerator,
        uint256 denominator,
        uint256 target
    ) internal pure returns (uint256 partialAmount) {
        partialAmount = numerator.safeMul(target).safeAdd(denominator.safeSub(1)).safeDiv(denominator);

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
        isError = remainder.safeMul(1000) >= numerator.safeMul(target);
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
        remainder = denominator.safeSub(remainder) % denominator;
        isError = remainder.safeMul(1000) >= numerator.safeMul(target);
        return isError;
    }
}
