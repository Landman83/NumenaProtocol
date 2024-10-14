// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@0x/contracts-utils/contracts/src/v06/interfaces/IOwnableV06.sol";

interface IOwnableFeatureMatchedOrders is IOwnableV06 {
    event Migrated(address caller, address migrator, address newOwner);

    function migrate(address target, bytes calldata data, address newOwner) external;
}