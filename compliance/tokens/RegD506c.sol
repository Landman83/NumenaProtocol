// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../compliance/modular/AbstractModule.sol";
import "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import "../registry/interface/IIdentityRegistry.sol";
import "../token/IToken.sol";

/**
 * @title RegD506cCompliance
 * @dev Implements compliance rules for Regulation D 506(c) securities
 * - Enforces 6-month holding period from offering date
 * - Restricts transfers to accredited investors only
 */
contract RegD506cCompliance is AbstractModule {
    // 6 month holding period in seconds
    uint256 public constant HOLDING_PERIOD = 180 days;
    
    // Claim topic ID for accredited investor status
    uint256 public constant ACCREDITED_CLAIM_TOPIC = 42; // Example value, would need to be standardized
    
    // Timestamp of when the offering started (set at deployment)
    uint256 public immutable offeringDate;
    
    // Events
    event OfferingInitiated(uint256 timestamp);
    
    /**
     * @dev Constructor sets the offering date
     */
    constructor() {
        offeringDate = block.timestamp;
        emit OfferingInitiated(block.timestamp);
    }
    
    /**
     * @dev Checks if a transfer is compliant with Reg D 506(c) rules
     */
    function moduleCheck(
        address _from, 
        address _to, 
        uint256 _amount, 
        address _token
    ) external view override returns (bool) {
        // Skip checks for minting
        if (_from == address(0)) {
            return true;
        }
        
        IToken token = IToken(_token);
        IIdentityRegistry registry = token.identityRegistry();
        
        // Verify recipient is an accredited investor
        require(_isAccreditedInvestor(registry, _to), "Recipient not accredited");
        
        // Check if holding period has elapsed
        require(block.timestamp >= offeringDate + HOLDING_PERIOD, "Transfer restricted during lockup period");
        
        return true;
    }
    
    /**
     * @dev No action needed post-transfer since we're tracking from offering date
     */
    function moduleTransferAction(
        address _from,
        address _to,
        uint256 _amount,
        address _token
    ) external override onlyToken(_token) {
        // No action needed
    }
    
    /**
     * @dev Checks if an address belongs to an accredited investor
     */
    function _isAccreditedInvestor(
        IIdentityRegistry _registry, 
        address _investor
    ) internal view returns (bool) {
        if (!_registry.isVerified(_investor)) {
            return false;
        }
        
        IIdentity identity = _registry.identity(_investor);
        return identity.hasValidClaim(ACCREDITED_CLAIM_TOPIC);
    }
    
    // Required overrides from AbstractModule
    function moduleName() external pure returns (bytes32) {
        return bytes32("RegD506cCompliance");
    }
    
    function moduleType() external pure returns (uint256) {
        return 2; // Transfer restriction type
    }
}