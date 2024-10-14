// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

library LibFeeCollector {
    function getFeeCollectorAddress(
        address controller,
        bytes32 initCodeHash,
        bytes32 poolId
    ) internal pure returns (address payable feeCollectorAddress) {
        return
            payable(
                address(
                    uint160(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    bytes1(0xff),
                                    controller,
                                    poolId,
                                    initCodeHash
                                )
                            )
                        )
                    )
                )
            );
    }
}