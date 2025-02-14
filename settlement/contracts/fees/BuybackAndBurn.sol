// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BuybackAndBurn is Ownable, ReentrancyGuard, Pausable {
    IERC20 public immutable PLATFORM_TOKEN;
    IERC20 public immutable FEE_TOKEN;
    
    uint256 public buybackFrequency; // Minimum time between buybacks
    uint256 public lastBuybackTime;
    uint256 public minBuybackAmount; // Minimum amount of fee tokens needed for buyback
    
    uint256 public burnFrequency; // Minimum time between burns
    uint256 public lastBurnTime;
    
    event FeesReceived(address indexed from, uint256 amount);
    event BuybackExecuted(uint256 feeTokenAmount, uint256 platformTokenAmount);
    event TokensBurned(uint256 amount);
    
    error TooSoonForBuyback(uint256 timeRemaining);
    error InsufficientFeesCollected(uint256 current, uint256 required);
    error TooSoonForBurn(uint256 timeRemaining);

    constructor(
        IERC20 platformToken, 
        IERC20 feeToken,
        uint256 _buybackFrequency,
        uint256 _minBuybackAmount
    ) {
        PLATFORM_TOKEN = platformToken;
        FEE_TOKEN = feeToken;
        buybackFrequency = _buybackFrequency;
        minBuybackAmount = _minBuybackAmount;
    }

    /// @notice Receives fees from collectors
    function receiveFees() external returns (bool) {
        uint256 amount = FEE_TOKEN.balanceOf(msg.sender);
        require(amount > 0, "No fees to transfer");
        require(
            FEE_TOKEN.transferFrom(msg.sender, address(this), amount),
            "Fee transfer failed"
        );
        emit FeesReceived(msg.sender, amount);
        return true;
    }

    /// @notice Executes buyback if conditions are met
    /// @param maxSlippage Maximum acceptable slippage in basis points (e.g., 100 = 1%)
    function executeBuyback(uint256 maxSlippage) external nonReentrant whenNotPaused {
        // Check timing
        if (block.timestamp < lastBuybackTime + buybackFrequency) {
            revert TooSoonForBuyback(lastBuybackTime + buybackFrequency - block.timestamp);
        }

        // Check accumulated fees
        uint256 feeBalance = FEE_TOKEN.balanceOf(address(this));
        if (feeBalance < minBuybackAmount) {
            revert InsufficientFeesCollected(feeBalance, minBuybackAmount);
        }

        // Execute market buy
        uint256 platformTokensBought = _executeMarketBuy(feeBalance, maxSlippage);
        lastBuybackTime = block.timestamp;
        
        emit BuybackExecuted(feeBalance, platformTokensBought);
    }

    /// @notice Executes burn if conditions are met
    function executeBurn() external nonReentrant whenNotPaused {
        // Check timing
        if (block.timestamp < lastBurnTime + burnFrequency) {
            revert TooSoonForBurn(lastBurnTime + burnFrequency - block.timestamp);
        }

        uint256 platformBalance = PLATFORM_TOKEN.balanceOf(address(this));
        require(platformBalance > 0, "No tokens to burn");
        
        _burn(platformBalance);
        lastBurnTime = block.timestamp;
    }

    /// @notice Executes market buy order through chosen DEX
    function _executeMarketBuy(
        uint256 feeTokenAmount,
        uint256 maxSlippage
    ) internal returns (uint256) {
        // TODO: Implement DEX market buy logic
        // This would integrate with your chosen DEX
        return 0; // placeholder
    }

    /// @notice Burns platform tokens
    function _burn(uint256 amount) internal {
        try PLATFORM_TOKEN.transfer(address(0), amount) {
            emit TokensBurned(amount);
        } catch {
            (bool success, ) = address(PLATFORM_TOKEN).call(
                abi.encodeWithSignature("burn(uint256)", amount)
            );
            require(success, "Burn failed");
            emit TokensBurned(amount);
        }
    }

    // Admin functions
    function updateBuybackFrequency(uint256 newFrequency) external onlyOwner {
        buybackFrequency = newFrequency;
    }

    function updateMinBuybackAmount(uint256 newAmount) external onlyOwner {
        minBuybackAmount = newAmount;
    }

    function updateBurnFrequency(uint256 newFrequency) external onlyOwner {
        burnFrequency = newFrequency;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
