// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/single_orders/CustomNativeOrderSettlement.sol";
import "../contracts/libs/LibCustomOrder.sol";
import "../contracts/libs/LibNativeOrder.sol";
import "../contracts/libs/LibSignature.sol";
import "../contracts/fees/CustomFeeCollectorController.sol";
import "./TestERC20.sol";
import "./TestStaking.sol";
import "./TestFeeCollectorController.sol";
import "../contracts/errors/LibNativeOrdersRichErrors.sol";

contract ConcreteNativeOrdersSettlement is NativeOrdersSettlement {
    constructor(
        address octagramAddress,
        IERC20 feeToken,
        IStaking staking,
        CustomFeeCollectorController feeCollectorController,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    ) NativeOrdersSettlement(
        octagramAddress,
        feeToken,
        staking,
        feeCollectorController,
        makerFeePercentage,
        takerFeePercentage
    ) {}

    // Implement any abstract methods here if necessary
}

contract TestCustomNativeOrderSettlement is Test {
    ConcreteNativeOrdersSettlement public settlement;
    TestERC20 public makerToken;
    TestERC20 public takerToken;
    TestERC20 public feeToken;  // Explicitly declare feeToken
    TestStaking public staking;
    TestFeeCollectorController public feeCollector;
    
    address public maker;
    address public taker;
    uint256 public makerPrivateKey;
    uint256 public takerPrivateKey;
    address public feeRecipient;
    
    uint256 constant makerFeePercentage = 10; // 0.1% in basis points
    uint256 constant takerFeePercentage = 20; // 0.2% in basis points
    
    address public registeredSigner;
    uint256 public registeredSignerPrivateKey;
    
    address public unregisteredSigner;
    uint256 public unregisteredSignerPrivateKey;
    
    function setUp() public {
        // Load environment variables
        maker = vm.addr(vm.envUint("MAKER_PRIVATE_KEY"));
        taker = vm.addr(vm.envUint("TAKER_PRIVATE_KEY"));
        makerPrivateKey = vm.envUint("MAKER_PRIVATE_KEY");
        takerPrivateKey = vm.envUint("TAKER_PRIVATE_KEY");
        feeRecipient = vm.envAddress("FEE_RECIPIENT_ADDRESS");

        // Verify that the derived addresses match the expected addresses
        require(maker == vm.envAddress("MAKER_ADDRESS"), "Maker address mismatch");
        require(taker == vm.envAddress("TAKER_ADDRESS"), "Taker address mismatch");

        makerToken = new TestERC20("Maker Token", "MTK", 1000000e18);
        takerToken = new TestERC20("Taker Token", "TTK", 1000000e18);
        feeToken = takerToken;  // Set feeToken equal to takerToken
        staking = new TestStaking(IERC20Token(address(takerToken))); // Use takerToken as staking token
        feeCollector = new TestFeeCollectorController();
        
        settlement = new ConcreteNativeOrdersSettlement(
            address(this),
            IERC20(address(feeToken)), // Use feeToken (which is takerToken)
            staking,
            CustomFeeCollectorController(address(feeCollector)),
            makerFeePercentage,
            takerFeePercentage
        );
        
        makerToken.mint(maker, 1000e18);
        takerToken.mint(taker, 1000e18);
        // Don't mint any fee tokens (takerTokens) to the maker
        
        vm.prank(maker);
        makerToken.approve(address(settlement), type(uint256).max);
        
        vm.prank(taker);
        takerToken.approve(address(settlement), type(uint256).max);

        registeredSigner = vm.envAddress("REGISTERED_SIGNER_ADDRESS");
        registeredSignerPrivateKey = vm.envUint("REGISTERED_SIGNER_PRIVATE_KEY");

        unregisteredSigner = vm.envAddress("UNREGISTERED_SIGNER_ADDRESS");
        unregisteredSignerPrivateKey = vm.envUint("UNREGISTERED_SIGNER_PRIVATE_KEY");
    }
    
    function testFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);

        // Print balances before the transaction
        console.log("--- Balances Before ---");
        console.log("Maker's makerToken balance:", makerToken.balanceOf(maker));
        console.log("Maker's takerToken balance:", takerToken.balanceOf(maker));
        console.log("Taker's makerToken balance:", makerToken.balanceOf(taker));
        console.log("Taker's takerToken balance:", takerToken.balanceOf(taker));

        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = settlement.fillLimitOrder(order, signature, order.takerAmount);

        // Print balances after the transaction
        console.log("--- Balances After ---");
        console.log("Maker's makerToken balance:", makerToken.balanceOf(maker));
        console.log("Maker's takerToken balance:", takerToken.balanceOf(maker));
        console.log("Taker's makerToken balance:", makerToken.balanceOf(taker));
        console.log("Taker's takerToken balance:", takerToken.balanceOf(taker));

        // Print filled amounts
        console.log("Taker token filled amount:", takerTokenFilledAmount);
        console.log("Maker token filled amount:", makerTokenFilledAmount);

        assertEq(takerTokenFilledAmount, order.takerAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount, "Incorrect maker token filled amount");
    }
    
    function testPartialFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint128 fillAmount = order.takerAmount / 2;
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = settlement.fillLimitOrder(order, signature, fillAmount);
        
        assertEq(takerTokenFilledAmount, fillAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount / 2, "Incorrect maker token filled amount");
    }
    
    function testCannotFillExpiredOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        order.expiry = uint64(block.timestamp - 1);  // Set expiry to past
        LibSignature.Signature memory signature = signOrder(order);
        
        // Get the order hash
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(
            LibNativeOrdersRichErrors.OrderNotFillableError.selector,
            orderHash,
            4 // 4 is the status code for expired orders
        ));
        settlement.fillLimitOrder(order, signature, order.takerAmount);
    }
    
    function testCannotFillCancelledOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        // Cancel the order
        vm.prank(maker);
        settlement.cancelLimitOrder(order);
        
        // Get the order hash
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        
        // Try to fill the cancelled order
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(
            LibNativeOrdersRichErrors.OrderNotFillableError.selector,
            orderHash,
            3 // 3 is the status code for cancelled orders
        ));
        settlement.fillLimitOrder(order, signature, order.takerAmount);
    }
    
    function testRegisterAllowedOrderSigner() public {
        vm.prank(maker);
        settlement.registerAllowedOrderSigner(registeredSigner, true);
        
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrderWithRegisteredSigner(order);
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, ) = settlement.fillLimitOrder(order, signature, order.takerAmount);
        
        assertEq(takerTokenFilledAmount, order.takerAmount, "Order should be fillable with registered signer");
    }
    
    function testCannotFillOrderWithUnregisteredSigner() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrderWithUnregisteredSigner(order);
        
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        vm.expectRevert(abi.encodeWithSelector(
            LibNativeOrdersRichErrors.OrderNotSignedByMakerError.selector,
            orderHash,
            unregisteredSigner,
            order.maker
        ));
        vm.prank(taker);
        settlement.fillLimitOrder(order, signature, order.takerAmount);
    }
    
    function testFeeCollection() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint256 makerTakerTokenBalanceBefore = takerToken.balanceOf(maker);
        uint256 takerTakerTokenBalanceBefore = takerToken.balanceOf(taker);
        uint256 feeRecipientBalanceBefore = feeToken.balanceOf(feeRecipient);
        
        vm.prank(taker);
        settlement.fillLimitOrder(order, signature, order.takerAmount);
        
        // Check taker's balance (should decrease by order.takerAmount + protocolFeeAmount)
        assertEq(
            takerToken.balanceOf(taker),
            takerTakerTokenBalanceBefore - order.takerAmount - order.protocolFeeAmount,
            "Incorrect taker token transfer"
        );
        
        // Check maker's balance (should increase by order.takerAmount)
        assertEq(
            takerToken.balanceOf(maker),
            makerTakerTokenBalanceBefore + order.takerAmount,
            "Incorrect maker token receipt"
        );
        
        // Check fee recipient's balance (should increase by protocolFeeAmount)
        assertEq(
            feeToken.balanceOf(feeRecipient),
            feeRecipientBalanceBefore + order.protocolFeeAmount,
            "Incorrect fee transfer to fee recipient"
        );

        // Logging for debugging
        console.log("Taker balance before:", takerTakerTokenBalanceBefore);
        console.log("Taker balance after:", takerToken.balanceOf(taker));
        console.log("Maker balance before:", makerTakerTokenBalanceBefore);
        console.log("Maker balance after:", takerToken.balanceOf(maker));
        console.log("Order taker amount:", order.takerAmount);
        console.log("Protocol fee amount:", order.protocolFeeAmount);
        console.log("Fee recipient balance before:", feeRecipientBalanceBefore);
        console.log("Fee recipient balance after:", feeToken.balanceOf(feeRecipient));
    }
    
    function createTestOrder() internal view returns (LibNativeOrder.LimitOrder memory) {
        return LibNativeOrder.LimitOrder({
            makerToken: IERC20Token(address(makerToken)),
            takerToken: IERC20Token(address(takerToken)),
            makerAmount: 100e18,
            takerAmount: 50e18,
            maker: maker,
            taker: address(0),
            sender: address(0),
            feeRecipient: feeRecipient,
            pool: bytes32(0),
            expiry: uint64(block.timestamp + 1 hours),
            salt: uint256(keccak256(abi.encodePacked(block.timestamp))),
            protocolFeeAmount: 1e18,
            makerIsBuyer: false // Set to false as requested
        });
    }
    
    function signOrder(LibNativeOrder.LimitOrder memory order) internal view returns (LibSignature.Signature memory) {
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(makerPrivateKey, orderHash);
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: v,
            r: r,
            s: s
        });
    }
    
    function signOrderWithSigner(LibNativeOrder.LimitOrder memory order, address signer) internal view returns (LibSignature.Signature memory) {
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(signer)), orderHash);
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: v,
            r: r,
            s: s
        });
    }
    
    function signOrderWithRegisteredSigner(LibNativeOrder.LimitOrder memory order) internal view returns (LibSignature.Signature memory) {
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(registeredSignerPrivateKey, orderHash);
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: v,
            r: r,
            s: s
        });
    }
    
    function signOrderWithUnregisteredSigner(LibNativeOrder.LimitOrder memory order) internal view returns (LibSignature.Signature memory) {
        bytes32 orderHash = settlement.getLimitOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unregisteredSignerPrivateKey, orderHash);
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: v,
            r: r,
            s: s
        });
    }
}
