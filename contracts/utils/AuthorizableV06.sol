// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

pragma solidity 0.8.26;

import "../interfaces/IAuthorizableV06.sol";
import "../errors/LibRichErrorsV06.sol";
import "../errors/LibAuthorizableRichErrorsV06.sol";
import "./OwnableV06.sol";

contract AuthorizableV06 is OwnableV06, IAuthorizableV06 {
    modifier onlyAuthorized() {
        _assertSenderIsAuthorized();
        _;
    }

    mapping(address => bool) public override authorized;
    address[] public override authorities;

    constructor() OwnableV06() {}

    function addAuthorizedAddress(address target) external override onlyOwner {
        _addAuthorizedAddress(target);
    }

    function removeAuthorizedAddress(address target) external override onlyOwner {
        if (!authorized[target]) {
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.TargetNotAuthorizedError(target));
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
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.SenderNotAuthorizedError(msg.sender));
        }
    }

    function _addAuthorizedAddress(address target) internal {
        if (target == address(0)) {
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.ZeroCantBeAuthorizedError());
        }

        if (authorized[target]) {
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.TargetAlreadyAuthorizedError(target));
        }

        authorized[target] = true;
        authorities.push(target);
        emit AuthorizedAddressAdded(target, msg.sender);
    }

    function _removeAuthorizedAddressAtIndex(address target, uint256 index) internal {
        if (!authorized[target]) {
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.TargetNotAuthorizedError(target));
        }
        if (index >= authorities.length) {
            LibRichErrorsV06.rrevert(LibAuthorizableRichErrorsV06.IndexOutOfBoundsError(index, authorities.length));
        }
        if (authorities[index] != target) {
            LibRichErrorsV06.rrevert(
                LibAuthorizableRichErrorsV06.AuthorizedAddressMismatchError(authorities[index], target)
            );
        }

        delete authorized[target];
        authorities[index] = authorities[authorities.length - 1];
        authorities.pop();
        emit AuthorizedAddressRemoved(target, msg.sender);
    }
}
