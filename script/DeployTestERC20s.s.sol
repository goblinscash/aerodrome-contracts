// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { TestERC20 } from "../test/utils/TestERC20.sol";

contract DeployTestERC20s is Script {
    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);

    constructor() {
    }

    function run() public {
        _deploySetupBefore();
        _coreScript();
        _deploySetupAfter();
    }

    function _deploySetupBefore() public {
        // start broadcasting transactions
        vm.startBroadcast(deployerAddress);
    }

    function deployTestERC20(string memory name, string memory ticker, uint decimals) public {
        TestERC20 token = new TestERC20(name, ticker, decimals);
        token.mint(deployerAddress, 1000000 * 10**decimals);
        console.log(name, "deployed at:", address(token));
    }

    function _coreScript() public {
        // deploy test tokens
        deployTestERC20("Test USDC", "tUSDC", 6);
        deployTestERC20("Test USDT", "tUSDT", 18);
        deployTestERC20("Test BCH", "tBCH", 18);
        deployTestERC20("Test ETH", "tETH", 18);
        deployTestERC20("Test GOB", "tGOB", 9);
    }

    function _deploySetupAfter() public {
        // finish broadcasting transactions
        vm.stopBroadcast();
    }
}
