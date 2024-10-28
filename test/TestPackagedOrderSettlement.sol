// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./TestERC20.sol";
import "forge-std/console.sol";
import "../contracts/core/single_orders/CustomNativeOrderSettlement.sol";
import "../contracts/libs/LibCustomOrder.sol";
import "../contracts/libs/LibNativeOrder.sol";
import "../contracts/libs/LibSignature.sol";
import "../contracts/fees/CustomFeeCollectorController.sol";
import "./TestStaking.sol";
import "./TestFeeCollectorController.sol";
import "../contracts/errors/LibNativeOrdersRichErrors.sol";
import "forge-std/StdJson.sol";

// Create concrete implementation of NativeOrdersSettlement
contract ConcreteNativeOrdersSettlement is NativeOrdersSettlement {
    constructor(
        address octagramAddress,
        IERC20 feeToken,
        IStaking staking,
        CustomFeeCollectorController feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    )
        NativeOrdersSettlement(
            octagramAddress,
            feeToken,
            staking,
            feeCollectorController,
            makerFeePercentage,
            takerFeePercentage
        )
    {}
}

contract TestPackagedOrderSettlement is Test {
    ConcreteNativeOrdersSettlement settlement;  // Use our concrete implementation
    TestERC20 cashToken;     // USD token
    TestERC20 securityToken; // SKYR token
    
    // All test accounts (0-9)
    address[10] accounts;
    uint256[10] privateKeys;
    
    // Special addresses
    address feeRecipient;
    address registeredSigner;
    address unregisteredSigner;
    
    uint256 constant INITIAL_SUPPLY = 0;
    uint256 constant TEST_AMOUNT = 1000 * 10**18; // 1000 tokens with 18 decimals
    uint16 constant MAKER_FEE_BPS = 10; // 0.1%
    uint16 constant TAKER_FEE_BPS = 20; // 0.2%

    function setUp() public {
        // Load all test accounts (0-9)
        for(uint i = 0; i < 10; i++) {
            accounts[i] = vm.envAddress(string.concat("ACCOUNT_", vm.toString(i), "_ADDRESS"));
            privateKeys[i] = vm.envUint(string.concat("ACCOUNT_", vm.toString(i), "_PRIVATE_KEY"));
        }

        // Load special addresses
        feeRecipient = vm.envAddress("FEE_RECIPIENT_ADDRESS");
        registeredSigner = vm.envAddress("REGISTERED_SIGNER_ADDRESS");
        unregisteredSigner = vm.envAddress("UNREGISTERED_SIGNER_ADDRESS");
        
        // Deploy tokens with 0 initial supply
        cashToken = new TestERC20("USD Token", "USD", INITIAL_SUPPLY);
        securityToken = new TestERC20("Skyrim Token", "SKYR", INITIAL_SUPPLY);
        
        // Deploy test staking contract with cashToken as fee token
        TestStaking staking = new TestStaking(IERC20Token(address(cashToken)));
        
        // Deploy test fee collector with required parameters
        TestFeeCollectorController feeCollector = new TestFeeCollectorController(
            IERC20Token(address(cashToken)),  // feeToken
            IStaking(staking)                 // staking contract
        );

        // Deploy settlement contract with required parameters
        settlement = new ConcreteNativeOrdersSettlement(
            address(this),           // octagramAddress
            IERC20(cashToken),       // feeToken
            IStaking(staking),       // staking contract
            feeCollector,            // fee collector
            MAKER_FEE_BPS,          // makerFeePercentage
            TAKER_FEE_BPS           // takerFeePercentage
        );
        
        // Mint tokens and setup approvals for ALL test accounts
        for(uint i = 0; i < accounts.length; i++) {
            // Mint tokens
            cashToken.mintTo(accounts[i], TEST_AMOUNT);
            securityToken.mintTo(accounts[i], TEST_AMOUNT);
            
            // Setup approvals
            vm.startPrank(accounts[i]);
            cashToken.approve(address(settlement), type(uint256).max);
            securityToken.approve(address(settlement), type(uint256).max);
            vm.stopPrank();
        }

        // Also mint tokens to fee recipient if not already included
        if (feeRecipient != accounts[0] && 
            feeRecipient != accounts[1] && 
            feeRecipient != accounts[2] &&
            feeRecipient != accounts[3] &&
            feeRecipient != accounts[4] &&
            feeRecipient != accounts[5] &&
            feeRecipient != accounts[6] &&
            feeRecipient != accounts[7] &&
            feeRecipient != accounts[8] &&
            feeRecipient != accounts[9]) {
            cashToken.mintTo(feeRecipient, TEST_AMOUNT);
            securityToken.mintTo(feeRecipient, TEST_AMOUNT);
        }
    }

    // Helper function to verify token balances
    function assertBalances(
        address account,
        uint256 expectedCashBalance,
        uint256 expectedSecurityBalance
    ) internal view {
        assertEq(
            cashToken.balanceOf(account),
            expectedCashBalance,
            "Incorrect cash token balance"
        );
        assertEq(
            securityToken.balanceOf(account),
            expectedSecurityBalance,
            "Incorrect security token balance"
        );
    }

    // Helper to get addresses for logging/debugging
    function logAddresses() internal view {
        for(uint i = 0; i < accounts.length; i++) {
            console.log(string.concat("Account ", vm.toString(i), ":"), accounts[i]);
        }
        console.log("Fee recipient:", feeRecipient);
        console.log("Registered signer:", registeredSigner);
        console.log("Unregistered signer:", unregisteredSigner);
        console.log("Cash token:", address(cashToken));
        console.log("Security token:", address(securityToken));
    }

    // Helper to get token addresses for order creation
    function getTokenAddresses() internal view returns (address, address) {
        return (address(cashToken), address(securityToken));
    }

    // Helper to get private key for a given address
    function getPrivateKey(address account) internal view returns (uint256) {
        for(uint i = 0; i < accounts.length; i++) {
            if(accounts[i] == account) {
                return privateKeys[i];
            }
        }
        revert("Account not found");
    }

    function testLogTokenAddresses() public view {
        console.log("=== Deployed Token Addresses ===");
        console.log("USD Token (Cash):", address(cashToken));
        console.log("SKYR Token (Security):", address(securityToken));
        console.log("=============================");
    }

    using stdJson for string;

    function testSettlePackagedTrades() public {
        // Use absolute path
        string memory path = vm.projectRoot();
        path = string.concat(path, "/test/fixture_trades.json");
        string memory json = vm.readFile(path);
        
        // Get the number of trades
        uint256 length = json.readUint(".length");
        console.log("Number of trades to settle:", length);

        // Process each trade
        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string.concat("[", vm.toString(i), "]");
            
            // Extract trade data
            LibNativeOrder.LimitOrder memory order = LibNativeOrder.LimitOrder({
                makerToken: IERC20Token(json.readAddress(string.concat(basePath, ".makerToken"))),
                takerToken: IERC20Token(json.readAddress(string.concat(basePath, ".takerToken"))),
                makerAmount: uint128(json.readUint(string.concat(basePath, ".makerAmount"))),
                takerAmount: uint128(json.readUint(string.concat(basePath, ".takerAmount"))),
                protocolFeeAmount: 0,  // Set to 0 for now
                maker: json.readAddress(string.concat(basePath, ".maker")),
                taker: json.readAddress(string.concat(basePath, ".taker")),
                sender: json.readAddress(string.concat(basePath, ".sender")),
                feeRecipient: json.readAddress(string.concat(basePath, ".feeRecipient")),
                pool: bytes32(json.readBytes(string.concat(basePath, ".pool"))),
                expiry: uint64(json.readUint(string.concat(basePath, ".expiration"))),
                salt: json.readUint(string.concat(basePath, ".salt")),
                makerIsBuyer: json.readBool(string.concat(basePath, ".makerIsBuyer"))
            });

            // Extract both maker and taker signatures into combined OrderSignature
            NativeOrdersSettlement.OrderSignature memory signatures = NativeOrdersSettlement.OrderSignature({
                signatureType: LibSignature.SignatureType.EIP712,
                maker_v: uint8(json.readUint(string.concat(basePath, ".maker_v"))),
                maker_r: json.readBytes32(string.concat(basePath, ".maker_r")),
                maker_s: json.readBytes32(string.concat(basePath, ".maker_s")),
                taker_v: uint8(json.readUint(string.concat(basePath, ".taker_v"))),
                taker_r: json.readBytes32(string.concat(basePath, ".taker_r")),
                taker_s: json.readBytes32(string.concat(basePath, ".taker_s"))
            });

            // Record balances before settlement
            uint256 makerCashBefore = cashToken.balanceOf(order.maker);
            uint256 makerSecurityBefore = securityToken.balanceOf(order.maker);
            uint256 takerCashBefore = cashToken.balanceOf(order.taker);
            uint256 takerSecurityBefore = securityToken.balanceOf(order.taker);

            // Fill the limit order with both signatures
            uint128 takerTokenFillAmount = order.takerAmount; // Fill the entire order
            settlement.fillLimitOrder(order, signatures, takerTokenFillAmount);

            // Verify balances after settlement
            uint256 makerCashAfter = cashToken.balanceOf(order.maker);
            uint256 makerSecurityAfter = securityToken.balanceOf(order.maker);
            uint256 takerCashAfter = cashToken.balanceOf(order.taker);
            uint256 takerSecurityAfter = securityToken.balanceOf(order.taker);

            console.log("Filled trade", i);
            console.log("Maker:", order.maker);
            console.log("Taker:", order.taker);
            console.log("Maker token transfers:", makerSecurityBefore - makerSecurityAfter, makerCashAfter - makerCashBefore);
            console.log("Taker token transfers:", takerCashBefore - takerCashAfter, takerSecurityAfter - takerSecurityBefore);
        }
    }
}
