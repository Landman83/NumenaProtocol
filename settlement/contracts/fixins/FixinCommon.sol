// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../errors/LibRichErrorsV08.sol";
import "../errors/LibCommonRichErrors.sol";
import "../errors/LibOwnableRichErrors.sol";
import "../interfaces/IOwnableFeature.sol";
import "../interfaces/ISimpleFunctionRegistryFeature.sol";

/// @dev Common feature utilities for matched orders.
abstract contract FixinCommon {
    using LibRichErrorsV08 for bytes;

    /// @dev The implementation address of this feature.
    address internal immutable _implementation;

    /// @dev The caller must be this contract.
    modifier onlySelf() virtual {
        if (msg.sender != address(this)) {
            LibCommonRichErrors.OnlyCallableBySelfError(msg.sender).rrevert();
        }
        _;
    }

    /// @dev The caller of this function must be the owner.
    modifier onlyOwner() virtual {
        {
            address owner = IOwnableFeature(address(this)).owner();
            if (msg.sender != owner) {
                LibOwnableRichErrors.OnlyOwnerError(msg.sender, owner).rrevert();
            }
        }
        _;
    }

    constructor() {
        // Remember this feature's original address.
        _implementation = address(this);
    }

    /// @dev Registers a function implemented by this feature at `_implementation`.
    ///      Can and should only be called within a `migrate()`.
    /// @param selector The selector of the function whose implementation
    ///        is at `_implementation`.
    function _registerFeatureFunction(bytes4 selector) internal {
        ISimpleFunctionRegistryFeature(address(this)).extend(selector, _implementation);
    }

    /// @dev Encode a feature version as a `uint256`.
    /// @param major The major version number of the feature.
    /// @param minor The minor version number of the feature.
    /// @param revision The revision number of the feature.
    /// @return encodedVersion The encoded version number.
    function _encodeVersion(
        uint32 major,
        uint32 minor,
        uint32 revision
    ) internal pure returns (uint256 encodedVersion) {
        return (uint256(major) << 64) | (uint256(minor) << 32) | uint256(revision);
    }
}