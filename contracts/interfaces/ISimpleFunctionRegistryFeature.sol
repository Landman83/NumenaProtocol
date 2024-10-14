// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

interface ISimpleFunctionRegistryFeatureMatchedOrders {
    event ProxyFunctionUpdated(bytes4 indexed selector, address oldImpl, address newImpl);

    function rollback(bytes4 selector, address targetImpl) external;

    function extend(bytes4 selector, address impl) external;

    function getRollbackLength(bytes4 selector) external view returns (uint256 rollbackLength);

    function getRollbackEntryAtIndex(bytes4 selector, uint256 idx) external view returns (address impl);
}