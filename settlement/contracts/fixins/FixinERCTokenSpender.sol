// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../token/IToken.sol";
import "../roles/AgentRole.sol";
import "../compliance/modular/reg-frameworks/Reg506c.sol";
import "../compliance/modular/ModularCompliance.sol";
import "../tokens/IERC3643Token.sol";
import "./FixinTokenSpender.sol";

/**
 * @title AtomicSwapSettlement
 * @dev Provides atomic settlement functionality for ERC-3643 tokens
 * Can be inherited by 0x settlement contracts
 */
contract FixinERC3643TokenSpender is OwnableUpgradeable {
    
    struct Order {
        address maker;
        address taker;  // Zero address for open orders
        address makerToken;
        address takerToken;
        uint256 makerAmount;
        uint256 takerAmount;
        uint256 expiry;
        bytes32 salt;   // Unique identifier for the order
    }

    // Mapping of filled/cancelled orders
    mapping(bytes32 => bool) public orderStatus;
    
    // Events
    event SwapExecuted(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        address makerToken,
        address takerToken,
        uint256 makerAmount,
        uint256 takerAmount
    );

    event OrderCancelled(bytes32 indexed orderHash);

    /**
     * @dev Initializes the contract
     */
    function initialize() external initializer {
        __Ownable_init();
    }

    /**
     * @dev Executes an atomic swap between ERC-3643 tokens
     * @param order The order details
     * @param makerSignature Maker's signature of the order
     * @param takerSignature Taker's signature of the order (if required)
     */
    function executeSwap(
        Order memory order,
        bytes memory makerSignature,
        bytes memory takerSignature
    ) external returns (bool) {
        bytes32 orderHash = _hashOrder(order);
        require(!orderStatus[orderHash], "Order already executed or cancelled");
        require(block.timestamp <= order.expiry, "Order expired");
        require(msg.sender == order.taker || order.taker == address(0), "Invalid taker");
        
        // Verify signatures
        require(_verifySignature(orderHash, order.maker, makerSignature), "Invalid maker signature");
        if (order.taker != address(0)) {
            require(_verifySignature(orderHash, order.taker, takerSignature), "Invalid taker signature");
        }

        // Mark order as filled
        orderStatus[orderHash] = true;

        // Execute the swap
        bool success = _executeTransfers(order);
        require(success, "Transfer failed");

        emit SwapExecuted(
            orderHash,
            order.maker,
            msg.sender,
            order.makerToken,
            order.takerToken,
            order.makerAmount,
            order.takerAmount
        );

        return true;
    }

    /**
     * @dev Cancels an order
     * @param order The order to cancel
     */
    function cancelOrder(Order memory order) external {
        require(msg.sender == order.maker, "Only maker can cancel");
        bytes32 orderHash = _hashOrder(order);
        require(!orderStatus[orderHash], "Order already executed or cancelled");
        
        orderStatus[orderHash] = true;
        emit OrderCancelled(orderHash);
    }

    /**
     * @dev Executes the token transfers
     * @param order The order details
     */
    function _executeTransfers(Order memory order) internal returns (bool) {
        // Check compliance for both sides before executing any transfers
        if (_isERC3643(order.makerToken)) {
            require(
                _checkReg506cCompliance(order.makerToken, order.maker, msg.sender, order.makerAmount),
                "Maker fails Reg506c compliance"
            );
        }
        
        if (_isERC3643(order.takerToken)) {
            require(
                _checkReg506cCompliance(order.takerToken, msg.sender, order.maker, order.takerAmount),
                "Taker fails Reg506c compliance"
            );
        }

        // Execute transfers only after both sides pass compliance
        if (_isERC3643(order.makerToken)) {
            require(
                _executeERC3643Transfer(order.makerToken, order.maker, msg.sender, order.makerAmount),
                "Maker transfer failed"
            );
        } else {
            require(
                IERC20(order.makerToken).transferFrom(order.maker, msg.sender, order.makerAmount),
                "Maker transfer failed"
            );
        }

        if (_isERC3643(order.takerToken)) {
            require(
                _executeERC3643Transfer(order.takerToken, msg.sender, order.maker, order.takerAmount),
                "Taker transfer failed"
            );
        } else {
            require(
                IERC20(order.takerToken).transferFrom(msg.sender, order.maker, order.takerAmount),
                "Taker transfer failed"
            );
        }

        return true;
    }

    /**
     * @dev Executes a transfer for an ERC-3643 token
     */
    function _executeERC3643Transfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        // Only check transfer agent approval here since compliance was checked earlier
        if (_requiresTransferApproval(token)) {
            require(
                AgentRole(token).isAgent(msg.sender),
                "Caller must be transfer agent"
            );
        }
        
        return IToken(token).transferFrom(from, to, amount);
    }

    /**
     * @dev Checks if a token is an ERC-3643 token
     */
    function _isERC3643(address token) internal view returns (bool) {
        try IToken(token).identityRegistry() returns (IIdentityRegistry) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @dev Checks if a token requires transfer agent approval
     */
    function _requiresTransferApproval(address token) internal view returns (bool) {
        return _isERC3643(token);
    }

    /**
     * @dev Hashes an order for signing
     */
    function _hashOrder(Order memory order) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            order.maker,
            order.taker,
            order.makerToken,
            order.takerToken,
            order.makerAmount,
            order.takerAmount,
            order.expiry,
            order.salt
        ));
    }

    /**
     * @dev Verifies a signature
     */
    function _verifySignature(
        bytes32 hash,
        address signer,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            hash
        ));
        
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);
        
        return recoveredSigner == signer;
    }

    /**
     * @dev Splits a signature into r, s, v components
     */
    function _splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function _checkReg506cCompliance(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal view returns (bool) {
        // Get compliance contract from token
        IToken tokenContract = IToken(token);
        address complianceAddress = address(tokenContract.compliance());
        
        // Check if it's using Reg506c compliance
        ModularCompliance compliance = ModularCompliance(complianceAddress);
        address[] memory modules = compliance.getModules();
        
        bool isReg506c = false;
        Reg506c reg506cModule;
        
        for (uint i = 0; i < modules.length; i++) {
            try Reg506c(modules[i]).name() returns (string memory name) {
                if (keccak256(bytes(name)) == keccak256(bytes("Reg506c"))) {
                    isReg506c = true;
                    reg506cModule = Reg506c(modules[i]);
                    break;
                }
            } catch {
                continue;
            }
        }

        // If it's Reg506c, enforce compliance checks
        if (isReg506c) {
            return reg506cModule.moduleCheck(from, to, amount, complianceAddress);
        }

        return true; // Not Reg506c, no additional checks needed
    }
}