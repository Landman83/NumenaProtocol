// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./IOwnableV06.sol";

interface IAuthorizableV06 is IOwnableV06 {
    event AuthorizedAddressAdded(address indexed target, address indexed caller);
    event AuthorizedAddressRemoved(address indexed target, address indexed caller);

    function addAuthorizedAddress(address target) external;
    function removeAuthorizedAddress(address target) external;
    function removeAuthorizedAddressAtIndex(address target, uint256 index) external;
    function getAuthorizedAddresses() external view returns (address[] memory authorizedAddresses);
    function authorized(address addr) external view returns (bool isAuthorized);
    function authorities(uint256 idx) external view returns (address addr);
}
