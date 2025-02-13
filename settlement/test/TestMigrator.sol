// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../contracts/migrations/LibMigrate.sol";
import "../contracts/interfaces/IOwnableFeature.sol";

contract TestMigrator {
    event TestMigrateCalled(bytes callData, address owner);

    function succeedingMigrate() external returns (bytes4 success) {
        emit TestMigrateCalled(msg.data, IOwnableFeature(address(this)).owner());
        return LibMigrate.MIGRATE_SUCCESS;
    }

    function failingMigrate() external returns (bytes4 success) {
        emit TestMigrateCalled(msg.data, IOwnableFeature(address(this)).owner());
        return 0xdeadbeef;
    }

    function revertingMigrate() external pure {
        revert("OOPSIE");
    }
}