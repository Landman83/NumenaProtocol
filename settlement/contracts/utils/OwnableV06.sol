// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "../interfaces/IOwnableV06.sol";
import "../errors/LibRichErrorsV06.sol";
import "../errors/LibOwnableRichErrorsV06.sol";

contract OwnableV06 is IOwnableV06 {
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
            LibRichErrorsV06.rrevert(LibOwnableRichErrorsV06.TransferOwnerToZeroError());
        } else {
            owner = newOwner;
            emit OwnershipTransferred(msg.sender, newOwner);
        }
    }

    function _assertSenderIsOwner() internal view {
        if (msg.sender != owner) {
            LibRichErrorsV06.rrevert(LibOwnableRichErrorsV06.OnlyOwnerError(msg.sender, owner));
        }
    }
}
