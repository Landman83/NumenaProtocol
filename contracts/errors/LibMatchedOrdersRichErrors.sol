// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibMatchedOrdersRichErrors {
    function OrderNotFillableError(bytes32 orderHash, uint8 orderStatus) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("OrderNotFillableError(bytes32,uint8)")),
            orderHash,
            orderStatus
        );
    }

    function OrderNotSignedByMakerError(
        bytes32 orderHash,
        address signer,
        address maker
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("OrderNotSignedByMakerError(bytes32,address,address)")),
            orderHash,
            signer,
            maker
        );
    }

    function InvalidSignerError(address maker, address signer) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("InvalidSignerError(address,address)")),
            maker,
            signer
        );
    }

    function CancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("CancelSaltTooLowError(uint256,uint256)")),
            minValidSalt,
            oldMinValidSalt
        );
    }

    function FillOrKillFailedError(
        bytes32 orderHash,
        uint256 cashTokenFilledAmount,
        uint256 cashTokenFillAmount
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("FillOrKillFailedError(bytes32,uint256,uint256)")),
            orderHash,
            cashTokenFilledAmount,
            cashTokenFillAmount
        );
    }

    function OnlyOrderMakerAllowed(
        bytes32 orderHash,
        address sender,
        address maker
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("OnlyOrderMakerAllowed(bytes32,address,address)")),
            orderHash,
            sender,
            maker
        );
    }

    function BatchFillIncompleteError(
        bytes32 orderHash,
        uint256 cashTokenFilledAmount,
        uint256 cashTokenFillAmount
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(keccak256("BatchFillIncompleteError(bytes32,uint256,uint256)")),
            orderHash,
            cashTokenFilledAmount,
            cashTokenFillAmount
        );
    }
}