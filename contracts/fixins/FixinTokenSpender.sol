// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@0x/contracts-erc20/src/IERC20Token.sol";
import "@0x/contracts-utils/contracts/src/v06/LibSafeMathV06.sol";

abstract contract FixinTokenSpender {
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    function _transferERC20TokensFrom(IERC20Token token, address owner, address to, uint256 amount) internal {
        require(address(token) != address(this), "FixinTokenSpender/CANNOT_INVOKE_SELF");

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(owner, ADDRESS_MASK))
            mstore(add(ptr, 0x24), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), and(token, ADDRESS_MASK), 0, ptr, 0x64, ptr, 32)

            let rdsize := returndatasize()

            success := and(
                success,
                or(
                    iszero(rdsize),
                    and(
                        iszero(lt(rdsize, 32)),
                        eq(mload(ptr), 1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _transferERC20Tokens(IERC20Token token, address to, uint256 amount) internal {
        require(address(token) != address(this), "FixinTokenSpender/CANNOT_INVOKE_SELF");

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), and(token, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32)

            let rdsize := returndatasize()

            success := and(
                success,
                or(
                    iszero(rdsize),
                    and(
                        iszero(lt(rdsize, 32)),
                        eq(mload(ptr), 1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _transferEth(address payable recipient, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "FixinTokenSpender::_transferEth/TRANSFER_FAILED");
        }
    }

    function _getSpendableERC20BalanceOf(IERC20Token token, address owner) internal view returns (uint256) {
        return LibSafeMathV06.min256(token.allowance(owner, address(this)), token.balanceOf(owner));
    }
}