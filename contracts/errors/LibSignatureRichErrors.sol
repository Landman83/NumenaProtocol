// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;


library LibMatchedOrdersSignatureRichErrors {
    enum SignatureValidationErrorCodes {
        ALWAYS_INVALID,
        INVALID_LENGTH,
        UNSUPPORTED,
        ILLEGAL,
        WRONG_SIGNER,
        BAD_SIGNATURE_DATA
    }

    function SignatureValidationError(
        SignatureValidationErrorCodes code,
        bytes32 hash,
        address signerAddress,
        bytes memory signature
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("SignatureValidationError(uint8,bytes32,address,bytes)")),
                code,
                hash,
                signerAddress,
                signature
            );
    }

    function SignatureValidationError(
        SignatureValidationErrorCodes code,
        bytes32 hash
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("SignatureValidationError(uint8,bytes32)")), code, hash);
    }
}