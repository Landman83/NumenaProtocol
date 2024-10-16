// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibNativeOrdersRichErrors {
    error ProtocolFeeRefundFailed(address receiver, uint256 refundAmount);
    error OrderNotFillableByOriginError(bytes32 orderHash, address txOrigin, address orderTxOrigin);
    error OrderNotFillableError(bytes32 orderHash, uint8 orderStatus);
    error OrderNotSignedByMakerError(bytes32 orderHash, address signer, address maker);
    error InvalidSignerError(address maker, address signer);
    error OrderNotFillableBySenderError(bytes32 orderHash, address sender, address orderSender);
    error OrderNotFillableByTakerError(bytes32 orderHash, address taker, address orderTaker);
    error CancelSaltTooLowError(uint256 minValidSalt, uint256 oldMinValidSalt);
    error FillOrKillFailedError(bytes32 orderHash, uint256 takerTokenFilledAmount, uint256 takerTokenFillAmount);
    error OnlyOrderMakerAllowed(bytes32 orderHash, address sender, address maker);
    error BatchFillIncompleteError(bytes32 orderHash, uint256 takerTokenFilledAmount, uint256 takerTokenFillAmount);
    error InsufficientFillAmount(bytes32 orderHash, uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount);
    
}
