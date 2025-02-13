// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./LibStorage.sol";

library LibNativeOrdersStorage {
    struct Storage {
        mapping(bytes32 => uint256) orderHashToTakerTokenFilledAmount;
        mapping(address => mapping(address => mapping(address => uint256))) limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt;
        mapping(address => mapping(address => mapping(address => uint256))) rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt;
        mapping(address => mapping(address => bool)) originRegistry;
        mapping(address => mapping(address => bool)) orderSignerRegistry;
    }

    function getStorage() internal pure returns (Storage storage stor) {
        uint256 storageSlot = LibStorage.getStorageSlot(LibStorage.StorageId.NativeOrders);
        assembly {
            stor.slot := storageSlot
        }
    }
}