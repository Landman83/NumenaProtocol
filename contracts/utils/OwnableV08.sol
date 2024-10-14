// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../interfaces/IOwnableV08.sol";
import "../errors/LibRichErrorsV08.sol";
import "../errors/LibOwnableRichErrorsV08.sol";

contract OwnableV08 is IOwnableV08 {
    address public override owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        _assertSenderIsOwner();
        _;
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == address(0)) {
            LibRichErrorsV08.rrevert(LibOwnableRichErrorsV08.TransferOwnerToZeroError());
        } else {
            owner = newOwner;
            emit OwnershipTransferred(msg.sender, newOwner);
        }
    }

    function _assertSenderIsOwner() internal view {
        if (msg.sender != owner) {
            LibRichErrorsV08.rrevert(LibOwnableRichErrorsV08.OnlyOwnerError(msg.sender, owner));
        }
    }
}
