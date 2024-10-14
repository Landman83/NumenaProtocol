// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../errors/LibRichErrorsV06.sol";
import "../errors/LibSignatureRichErrors.sol";

library LibSignatureMatchedOrders {
    using LibRichErrorsV06 for bytes;

    uint256 private constant ETH_SIGN_HASH_PREFIX = 0x19457468657265756d205369676e6564204d6573736167653a0a333200000000;
    uint256 private constant ECDSA_SIGNATURE_R_LIMIT =
        uint256(0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141);
    uint256 private constant ECDSA_SIGNATURE_S_LIMIT = ECDSA_SIGNATURE_R_LIMIT / 2 + 1;

    enum SignatureType {
        ILLEGAL,
        INVALID,
        EIP712,
        ETHSIGN,
        PRESIGNED
    }

    struct Signature {
        SignatureType signatureType;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function getSignerOfHash(bytes32 hash, Signature memory signature) internal pure returns (address recovered) {
        _validateHashCompatibleSignature(hash, signature);

        if (signature.signatureType == SignatureType.EIP712) {
            recovered = ecrecover(hash, signature.v, signature.r, signature.s);
        } else if (signature.signatureType == SignatureType.ETHSIGN) {
            bytes32 ethSignHash;
            assembly {
                mstore(0, ETH_SIGN_HASH_PREFIX)
                mstore(28, hash)
                ethSignHash := keccak256(0, 60)
            }
            recovered = ecrecover(ethSignHash, signature.v, signature.r, signature.s);
        }
        if (recovered == address(0)) {
            LibSignatureRichErrors
                .SignatureValidationError(LibSignatureRichErrors.SignatureValidationErrorCodes.BAD_SIGNATURE_DATA, hash)
                .rrevert();
        }
    }

    function _validateHashCompatibleSignature(bytes32 hash, Signature memory signature) private pure {
        if (uint256(signature.r) >= ECDSA_SIGNATURE_R_LIMIT || uint256(signature.s) >= ECDSA_SIGNATURE_S_LIMIT) {
            LibSignatureRichErrors
                .SignatureValidationError(LibSignatureRichErrors.SignatureValidationErrorCodes.BAD_SIGNATURE_DATA, hash)
                .rrevert();
        }

        if (signature.signatureType == SignatureType.ILLEGAL) {
            LibSignatureRichErrors
                .SignatureValidationError(LibSignatureRichErrors.SignatureValidationErrorCodes.ILLEGAL, hash)
                .rrevert();
        }

        if (signature.signatureType == SignatureType.INVALID) {
            LibSignatureRichErrors
                .SignatureValidationError(LibSignatureRichErrors.SignatureValidationErrorCodes.ALWAYS_INVALID, hash)
                .rrevert();
        }

        if (signature.signatureType == SignatureType.PRESIGNED) {
            LibSignatureRichErrors
                .SignatureValidationError(LibSignatureRichErrors.SignatureValidationErrorCodes.UNSUPPORTED, hash)
                .rrevert();
        }
    }
}