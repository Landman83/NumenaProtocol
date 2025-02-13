// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

/// @dev Basic interface for a matched orders feature contract.
interface IFeature {
    /// @dev The name of this feature set.
    function FEATURE_NAME() external view returns (string memory name);

    /// @dev The version of this feature set.
    function FEATURE_VERSION() external view returns (uint256 version);

    /// @dev Initializes this feature.
    function initialize() external;

    /// @dev Checks if this feature is compatible with the given feature set.
    /// @param featureSet The address of the feature set to check compatibility with.
    /// @return True if compatible, false otherwise.
    function isCompatibleWith(address featureSet) external view returns (bool);
}