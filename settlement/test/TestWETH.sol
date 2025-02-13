// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

/*
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../contracts/tokens/IEtherToken.sol";

contract TestWETH is ERC20, ReentrancyGuard, IEtherToken {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Wrapped Ether", "WETH") {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable override {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public override {
        withdraw(wad, msg.sender);
    }

    function withdraw(uint256 wad, address withdrawTo) public nonReentrant override {
        require(balanceOf(msg.sender) >= wad, "TestWETH: insufficient balance");
        _burn(msg.sender, wad);
        (bool success, ) = withdrawTo.call{value: wad}("");
        require(success, "TestWETH: ETH transfer failed");
        emit Withdrawal(msg.sender, wad);
    }

    // Additional functions for testing purposes

    function mintTo(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) public {
        require(from == msg.sender || allowance(from, msg.sender) >= amount, "TestWETH: burn amount exceeds allowance");
        _burn(from, amount);
    }

    // Function to simulate a transfer failure
    function simulateTransferFailure(bool shouldFail) public {
        assembly {
            sstore(0, shouldFail)
        }
    }

    // Override transfer function to allow simulated failures
    function transfer(address to, uint256 amount) public virtual override(ERC20, IEtherToken) returns (bool) {
        bool shouldFail;
        assembly {
            shouldFail := sload(0)
        }
        require(!shouldFail, "TestWETH: simulated transfer failure");
        return super.transfer(to, amount);
    }

    // Override transferFrom function to allow simulated failures
    function transferFrom(address from, address to, uint256 amount) public virtual override(ERC20, IEtherToken) returns (bool) {
        bool shouldFail;
        assembly {
            shouldFail := sload(0)
        }
        require(!shouldFail, "TestWETH: simulated transfer failure");
        return super.transferFrom(from, to, amount);
    }

    // Function to drain ETH from the contract (for testing purposes)
    function drainETH(address to, uint256 amount) public {
        require(address(this).balance >= amount, "TestWETH: insufficient ETH balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "TestWETH: ETH transfer failed");
    }
}
*/