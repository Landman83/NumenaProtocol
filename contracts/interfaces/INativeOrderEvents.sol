// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../libs/LibSignature.sol";
import "../libs/LibNativeOrder.sol";

interface INativeOrdersEvents {
    event LimitOrderFilled(
        bytes32 orderHash,
        address maker,
        address taker,
        address feeRecipient,
        address makerToken,
        address takerToken,
        uint128 takerTokenFilledAmount,
        uint128 makerTokenFilledAmount,
        uint128 takerTokenFeeFilledAmount,
        uint256 protocolFeePaid,
        bytes32 pool
    );

    event RfqOrderFilled(
        bytes32 orderHash,
        address maker,
        address taker,
        address makerToken,
        address takerToken,
        uint128 takerTokenFilledAmount,
        uint128 makerTokenFilledAmount,
        bytes32 pool
    );

    event OrderCancelled(bytes32 orderHash, address maker);

    event PairCancelledLimitOrders(address maker, address makerToken, address takerToken, uint256 minValidSalt);

    event PairCancelledRfqOrders(address maker, address makerToken, address takerToken, uint256 minValidSalt);

    event RfqOrderOriginsAllowed(address origin, address[] addrs, bool allowed);

    event OrderSignerRegistered(address maker, address signer, bool allowed);
}