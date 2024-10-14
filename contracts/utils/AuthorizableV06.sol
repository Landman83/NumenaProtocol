// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

pragma solidity 0.8.26;

import "../interfaces/IAuthorizableV08.sol";
import "../errors/LibRichErrorsV08.sol";
import "../errors/LibAuthorizableRichErrorsV08.sol";
import "./OwnableV08.sol";

contract AuthorizableV06 is OwnableV08, IAuthorizableV08 {
    modifier onlyAuthorized() {
        _assertSenderIsAuthorized();
        _;
    }

    mapping(address => bool) public override authorized;
    address[] public override authorities;

    constructor() OwnableV08() {}

    function addAuthorizedAddress(address target) external override onlyOwner {
        _addAuthorizedAddress(target);
    }

    function removeAuthorizedAddress(address target) external override onlyOwner {
        if (!authorized[target]) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.TargetNotAuthorizedError(target));
        }
        for (uint256 i = 0; i < authorities.length; i++) {
            if (authorities[i] == target) {
                _removeAuthorizedAddressAtIndex(target, i);
                break;
            }
        }
    }

    function removeAuthorizedAddressAtIndex(address target, uint256 index) external override onlyOwner {
        _removeAuthorizedAddressAtIndex(target, index);
    }

    function getAuthorizedAddresses() external view override returns (address[] memory) {
        return authorities;
    }

    function _assertSenderIsAuthorized() internal view {
        if (!authorized[msg.sender]) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.SenderNotAuthorizedError(msg.sender));
        }
    }

    function _addAuthorizedAddress(address target) internal {
        if (target == address(0)) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.ZeroCantBeAuthorizedError());
        }

        if (authorized[target]) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.TargetAlreadyAuthorizedError(target));
        }

        authorized[target] = true;
        authorities.push(target);
        emit AuthorizedAddressAdded(target, msg.sender);
    }

    function _removeAuthorizedAddressAtIndex(address target, uint256 index) internal {
        if (!authorized[target]) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.TargetNotAuthorizedError(target));
        }
        if (index >= authorities.length) {
            LibRichErrorsV08.rrevert(LibAuthorizableRichErrorsV08.IndexOutOfBoundsError(index, authorities.length));
        }
        if (authorities[index] != target) {
            LibRichErrorsV08.rrevert(
                LibAuthorizableRichErrorsV08.AuthorizedAddressMismatchError(authorities[index], target)
            );
        }

        delete authorized[target];
        authorities[index] = authorities[authorities.length - 1];
        authorities.pop();
        emit AuthorizedAddressRemoved(target, msg.sender);
    }
}
