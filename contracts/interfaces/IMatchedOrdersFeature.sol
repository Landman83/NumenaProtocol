// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@0x/contracts-erc20/contracts/src/v06/IERC20Token.sol";
import "./libs/LibSignature.sol";
import "./libs/LibMatchedOrder.sol";
import "./IMatchedOrdersEvents.sol";

interface IMatchedOrdersSettlementFeature is IMatchedOrdersEvents {
    struct Order {
        address cashToken;
        address securityToken;
        uint128 cashAmount;
        uint128 securityAmount;
        address buyer;
        address seller;
        uint256 salt;
    }

    struct OrderInfo {
        uint8 status;
        bytes32 orderHash;
        uint128 cashTokenFilledAmount;
    }

    struct MatchedOrder {
        Order order;
        LibSignature.Signature signature;
    }

    function batchSettleMatchedOrders(MatchedOrder[] calldata matchedOrders) external payable returns (uint128[] memory cashTokenFilledAmounts, uint128[] memory securityTokenFilledAmounts);

    function getOrderInfo(Order calldata order) external view returns (OrderInfo memory orderInfo);

    function getOrderHash(Order calldata order) external view returns (bytes32 orderHash);

    function getProtocolFeeMultiplier() external view returns (uint32 multiplier);

    function batchGetOrderRelevantStates(
        Order[] calldata orders,
        LibSignature.Signature[] calldata signatures
    )
        external
        view
        returns (
            OrderInfo[] memory orderInfos,
            uint128[] memory actualFillableCashTokenAmounts,
            bool[] memory isSignatureValids
        );

    function isValidOrderSigner(address seller, address signer) external view returns (bool isAllowed);

    function transferProtocolFeesForPools(bytes32[] calldata poolIds) external;

    event OrderSettled(
        bytes32 indexed orderHash,
        address indexed seller,
        address indexed buyer,
        uint128 cashTokenFilledAmount,
        uint128 securityTokenFilledAmount
    );

    event ProtocolFeeUnspent(uint256 unspentAmount);
}