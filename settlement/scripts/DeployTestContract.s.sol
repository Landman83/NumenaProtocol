// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../test/TestERC20.sol";
import "../test/TestStaking.sol";
import "../test/TestFeeCollectorController.sol";
import "../test/ConcreteSettlement.sol";
import "../contracts/interfaces/IStaking.sol";
import "../contracts/fees/CustomFeeCollectorController.sol";
import "../contracts/tokens/IERC20Token.sol";

contract DeployTestContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ACCOUNT_0_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy test tokens first with large initial supply
        uint256 initialSupply = 1000000 * 10**18; // 1 million tokens
        TestERC20 cashToken = new TestERC20("USD", "USD", initialSupply);
        TestERC20 securityToken = new TestERC20("SKYR", "SKYR", initialSupply);
        
        // Deploy test staking contract with USD as fee token
        TestStaking staking = new TestStaking(IERC20Token(address(cashToken)));
        
        // Deploy test fee collector controller with USD as fee token
        TestFeeCollectorController feeCollector = new TestFeeCollectorController(
            IERC20Token(address(cashToken)),
            staking
        );
        
        // Deploy the settlement contract
        ConcreteNativeOrdersSettlement settlement = new ConcreteNativeOrdersSettlement(
            address(0), // octagram address
            IERC20(cashToken), // fee token
            staking, // staking
            feeCollector, // fee collector
            10, // maker fee percentage
            20  // taker fee percentage
        );

        console.log("USD Token (Cash) deployed to:", address(cashToken));
        console.log("SKYR Token (Security) deployed to:", address(securityToken));
        console.log("Staking Contract deployed to:", address(staking));
        console.log("Fee Collector deployed to:", address(feeCollector));
        console.log("Settlement Contract deployed to:", address(settlement));

        vm.stopBroadcast();
    }
}
