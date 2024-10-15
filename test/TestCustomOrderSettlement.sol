// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;


import "forge-std/Test.sol";
import "../contracts/core/single_orders/CustomNativeOrderSettlement.sol";
import "../contracts/libs/LibCustomOrder.sol";
import "../contracts/libs/LibSignature.sol";
import "../contracts/fees/CustomFeeCollectorController.sol";
import "./TestERC20.sol";
import "./TestStaking.sol";
import "./TestFeeCollectorController.sol";

// Minimal concrete implementation of NativeOrdersSettlement
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

    // Implement any abstract methods here
    // For example:
    // function someAbstractMethod() public override {
    //     // Minimal implementation
    // }
}

// Wrapper contract for testing
contract TestNativeOrdersSettlement {
    ConcreteNativeOrdersSettlement public settlement;

    constructor(
        address octagramAddress,
        IERC20 feeToken,
        IStaking staking,
        TestFeeCollectorController testFeeCollector,
        uint256 makerFeePercentage,
        uint256 takerFeePercentage
    ) {
        // Cast TestFeeCollectorController to FeeCollectorController
        CustomFeeCollectorController feeCollector = CustomFeeCollectorController(address(testFeeCollector));
        
        settlement = new ConcreteNativeOrdersSettlement(
            octagramAddress,
            feeToken,
            staking,
            feeCollector,
            makerFeePercentage,
            takerFeePercentage
        );
    }

    // Wrapper function for fillLimitOrder
    function fillLimitOrder(
        LibNativeOrder.LimitOrder memory order,
        LibSignature.Signature memory signature,
        uint128 takerTokenFillAmount
    ) public payable returns (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) {
        return settlement.fillLimitOrder(order, signature, takerTokenFillAmount);
    }

    // Add wrapper function for cancelLimitOrder
    function cancelLimitOrder(LibNativeOrder.LimitOrder memory order) public {
        settlement.cancelLimitOrder(order);
    }

    // Add wrapper function for registerAllowedOrderSigner
    function registerAllowedOrderSigner(address signer, bool allowed) public {
        settlement.registerAllowedOrderSigner(signer, allowed);
    }

    // Add other wrapper functions as needed
}

contract NativeOrdersSettlementTest is Test {
    TestNativeOrdersSettlement public testSettlement;
    TestERC20 public makerToken;
    TestERC20 public takerToken;
    TestERC20 public feeToken;
    TestStaking public staking;
    TestFeeCollectorController public feeCollector;
    
    address public maker = address(1);
    address public taker = address(2);
    address public feeRecipient = address(3);
    
    uint256 constant makerFeePercentage = 10;
    uint256 constant takerFeePercentage = 20;
    
    function setUp() public {
        makerToken = new TestERC20("Maker Token", "MTK", 1000000e18);
        takerToken = new TestERC20("Taker Token", "TTK", 1000000e18);
        feeToken = makerToken;
        staking = new TestStaking(IERC20Token(address(feeToken)));
        feeCollector = new TestFeeCollectorController();
        
        testSettlement = new TestNativeOrdersSettlement(
            address(this),
            feeToken,
            staking,
            feeCollector,
            makerFeePercentage,
            takerFeePercentage
        );
        
        makerToken.mint(maker, 1000e18);
        takerToken.mint(taker, 1000e18);
        
        vm.prank(maker);
        makerToken.approve(address(testSettlement.settlement()), type(uint256).max);
        
        vm.prank(taker);
        takerToken.approve(address(testSettlement.settlement()), type(uint256).max);
    }
    
    function testFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint128 fillAmount = order.takerAmount;
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = testSettlement.fillLimitOrder{value: 1337 wei}(order, signature, fillAmount);
        
        assertEq(takerTokenFilledAmount, fillAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount, "Incorrect maker token filled amount");
        assertEq(IERC20Token(order.makerToken).balanceOf(taker), order.makerAmount, "Taker should receive maker tokens");
        assertEq(IERC20Token(order.takerToken).balanceOf(maker), order.takerAmount, "Maker should receive taker tokens");
    }
    
    function testPartialFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint128 fillAmount = order.takerAmount / 2;
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = testSettlement.fillLimitOrder{value: 1337 wei}(order, signature, fillAmount);
        
        assertEq(takerTokenFilledAmount, fillAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount / 2, "Incorrect maker token filled amount");
    }
    
    function testCannotFillExpiredOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        order.expiry = uint64(block.timestamp - 1);
        LibSignature.Signature memory signature = signOrder(order);
        
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(LibNativeOrdersRichErrors.OrderNotFillableError.selector, bytes32(0), uint8(3)));
        testSettlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
    }
    
    function testCannotFillCancelledOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        vm.prank(maker);
        testSettlement.cancelLimitOrder(order);
        
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(LibNativeOrdersRichErrors.OrderNotFillableError.selector, bytes32(0), uint8(2)));
        testSettlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
    }
    
    function testRegisterAllowedOrderSigner() public {
        address signer = address(4);
        
        vm.prank(maker);
        testSettlement.registerAllowedOrderSigner(signer, true);
        
        // Now create and fill an order signed by the registered signer
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrderWithSigner(order, signer);
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, ) = testSettlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
        
        assertEq(takerTokenFilledAmount, order.takerAmount, "Order should be fillable with registered signer");
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
            makerIsBuyer: true
        });
    }
    
    function signOrder(LibNativeOrder.LimitOrder memory order) internal pure returns (LibSignature.Signature memory) {
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: 27,
            r: bytes32(uint256(uint160(order.maker))),
            s: bytes32(order.salt)
        });
    }
    
    function signOrderWithSigner(LibNativeOrder.LimitOrder memory order, address signer) internal pure returns (LibSignature.Signature memory) {
        return LibSignature.Signature({
            signatureType: LibSignature.SignatureType.EIP712,
            v: 27,
            r: bytes32(uint256(uint160(signer))),
            s: bytes32(order.salt)
        });
    }
}
