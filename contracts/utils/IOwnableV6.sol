// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IOwnable {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferOwnership(address newOwner) external;

    function owner() external view returns (address ownerAddress);
}