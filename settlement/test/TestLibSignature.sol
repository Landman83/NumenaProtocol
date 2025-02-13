// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/libs/LibSignature.sol";

contract TestLibSignature {
    function getSignerOfHash(
        bytes32 hash,
        LibSignature.Signature calldata signature
    ) external pure returns (address signer) {
        return LibSignature.getSignerOfHash(hash, signature);
    }
}