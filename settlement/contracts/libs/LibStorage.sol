// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibStorage {
    uint256 private constant STORAGE_SLOT_EXP = 128;

    enum StorageId {
        Proxy,
        SimpleFunctionRegistry,
        Ownable,
        TokenSpender,
        TransformERC20,
        MetaTransactions,
        ReentrancyGuard,
        NativeOrders,
        OtcOrders,
        ERC721Orders,
        ERC1155Orders,
        MetaTransactionsV2
    }

    function getStorageSlot(StorageId storageId) internal pure returns (uint256 slot) {
        return (uint256(storageId) + 1) << STORAGE_SLOT_EXP;
    }
}