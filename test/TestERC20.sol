// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply) 
        ERC20(name, symbol) 
        Ownable(msg.sender)  // Initialize Ownable with the deployer as the initial owner
    {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    // Allow anyone to mint tokens to themselves for testing purposes
    function mintTo(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // Allow anyone to burn their own tokens for testing purposes
    function burnFrom(address from, uint256 amount) public {
        require(from == msg.sender || allowance(from, msg.sender) >= amount, "TestERC20: burn amount exceeds allowance");
        _burn(from, amount);
    }

    // Function to simulate a transfer failure
    function simulateTransferFailure(bool shouldFail) public {
        assembly {
            sstore(0, shouldFail)
        }
    }

    // Override transfer function to allow simulated failures
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        bool shouldFail;
        assembly {
            shouldFail := sload(0)
        }
        require(!shouldFail, "TestERC20: simulated transfer failure");
        return super.transfer(to, amount);
    }

    // Override transferFrom function to allow simulated failures
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        bool shouldFail;
        assembly {
            shouldFail := sload(0)
        }
        require(!shouldFail, "TestERC20: simulated transfer failure");
        return super.transferFrom(from, to, amount);
    }
}
