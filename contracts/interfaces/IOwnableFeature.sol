// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./IOwnableV08.sol";

interface IOwnableFeatureMatchedOrders is IOwnableV08 {
    event Migrated(address caller, address migrator, address newOwner);

    function migrate(address target, bytes calldata data, address newOwner) external;
}