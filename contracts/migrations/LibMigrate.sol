// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@0x/contracts-utils/contracts/src/v06/errors/LibRichErrorsV06.sol";
import "../errors/LibOwnableRichErrors.sol";

library LibMatchedOrdersMigrate {
    bytes4 internal constant MIGRATE_SUCCESS = 0x2c64c5ef;

    using LibRichErrorsV06 for bytes;

    function delegatecallMigrateFunction(address target, bytes memory data) internal {
        (bool success, bytes memory resultData) = target.delegatecall(data);
        if (!success || resultData.length != 32 || abi.decode(resultData, (bytes4)) != MIGRATE_SUCCESS) {
            LibMatchedOrdersOwnableRichErrors.MigrateCallFailedError(target, resultData).rrevert();
        }
    }
}

