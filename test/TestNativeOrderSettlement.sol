// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../contracts/core/single_orders/NativeOrderSettlement.sol";
import "../contracts/libs/LibNativeOrder.sol";
import "./TestERC20.sol";
import "./TestWETH.sol";
import "./TestStaking.sol";
import "./TestFeeCollectorController.sol";

contract NativeOrdersSettlementTest is Test {
    NativeOrdersSettlement public settlement;
    TestERC20 public makerToken;
    TestERC20 public takerToken;
    TestWETH public weth;
    TestStaking public staking;
    TestFeeCollectorController public feeCollector;
    
    address public maker = address(1);
    address public taker = address(2);
    address public feeRecipient = address(3);
    
    uint32 constant PROTOCOL_FEE_MULTIPLIER = 1337;
    
    function setUp() public {
        makerToken = new TestERC20("Maker Token", "MTK");
        takerToken = new TestERC20("Taker Token", "TTK");
        weth = new TestWETH();
        staking = new TestStaking();
        feeCollector = new TestFeeCollectorController();
        
        settlement = new NativeOrdersSettlement(
            address(this),
            weth,
            staking,
            feeCollector,
            PROTOCOL_FEE_MULTIPLIER
        );
        
        makerToken.mint(maker, 1000e18);
        takerToken.mint(taker, 1000e18);
        
        vm.prank(maker);
        makerToken.approve(address(settlement), type(uint256).max);
        
        vm.prank(taker);
        takerToken.approve(address(settlement), type(uint256).max);
    }
    
    function testFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint128 fillAmount = order.takerAmount;
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = settlement.fillLimitOrder{value: 1337 wei}(order, signature, fillAmount);
        
        assertEq(takerTokenFilledAmount, fillAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount, "Incorrect maker token filled amount");
        assertEq(makerToken.balanceOf(taker), order.makerAmount, "Taker should receive maker tokens");
        assertEq(takerToken.balanceOf(maker), order.takerAmount, "Maker should receive taker tokens");
    }
    
    function testPartialFillLimitOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        uint128 fillAmount = order.takerAmount / 2;
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount) = settlement.fillLimitOrder{value: 1337 wei}(order, signature, fillAmount);
        
        assertEq(takerTokenFilledAmount, fillAmount, "Incorrect taker token filled amount");
        assertEq(makerTokenFilledAmount, order.makerAmount / 2, "Incorrect maker token filled amount");
    }
    
    function testCannotFillExpiredOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        order.expiry = uint64(block.timestamp - 1);
        LibSignature.Signature memory signature = signOrder(order);
        
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(LibNativeOrdersRichErrors.OrderNotFillableError.selector, bytes32(0), uint8(3)));
        settlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
    }
    
    function testCannotFillCancelledOrder() public {
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrder(order);
        
        vm.prank(maker);
        settlement.cancelLimitOrder(order);
        
        vm.prank(taker);
        vm.expectRevert(abi.encodeWithSelector(LibNativeOrdersRichErrors.OrderNotFillableError.selector, bytes32(0), uint8(2)));
        settlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
    }
    
    function testRegisterAllowedOrderSigner() public {
        address signer = address(4);
        
        vm.prank(maker);
        settlement.registerAllowedOrderSigner(signer, true);
        
        // Now create and fill an order signed by the registered signer
        LibNativeOrder.LimitOrder memory order = createTestOrder();
        LibSignature.Signature memory signature = signOrderWithSigner(order, signer);
        
        vm.prank(taker);
        (uint128 takerTokenFilledAmount, ) = settlement.fillLimitOrder{value: 1337 wei}(order, signature, order.takerAmount);
        
        assertEq(takerTokenFilledAmount, order.takerAmount, "Order should be fillable with registered signer");
    }
    
    function createTestOrder() internal view returns (LibNativeOrder.LimitOrder memory) {
        return LibNativeOrder.LimitOrder({
            makerToken: address(makerToken),
            takerToken: address(takerToken),
            makerAmount: 100e18,
            takerAmount: 50e18,
            maker: maker,
            taker: address(0),
            sender: address(0),
            feeRecipient: feeRecipient,
            pool: bytes32(0),
            expiry: uint64(block.timestamp + 1 hours),
            salt: uint256(keccak256(abi.encodePacked(block.timestamp))),
            takerTokenFeeAmount: 1e18
        });
    }
    
    function signOrder(LibNativeOrder.LimitOrder memory order) internal view returns (LibSignature.Signature memory) {
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