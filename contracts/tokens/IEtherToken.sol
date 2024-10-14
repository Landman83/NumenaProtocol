// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./IERC20Token.sol";

interface IEtherToken is IERC20Token {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
