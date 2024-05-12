//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {CustomPoolFactoryExample} from "../contracts/CustomPoolFactoryExample.sol";
import {DeployPool} from "./DeployPool.s.sol";
import "./DeployHelpers.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TokenConfig} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import {HelperConfig} from "../utils/HelperConfig.sol";

/**
 * @title DeployFactoryAndPool
 * @author BuidlGuidl Labs
 * @notice Contracts deployed by this script will have their info saved into the frontend for hot reload
 * @notice This script deploys a pool factory, deploys a pool using the factory, and then initializes the pool with mock tokens
 * @notice Mock tokens and BPT will be sent to the PK set in the .env file
 * @dev Set the pool factory, pool deployment, and pool initialization configurations in `HelperConfig.s.sol`
 * @dev Then run this script with `yarn deploy:all`
 */
contract DeployFactoryAndPool is ScaffoldETHDeploy, DeployPool {
    error InvalidPrivateKey(string);

    // Tokens for pool (also requires configuration of `TokenConfig` in `getPoolConfig` function of HelperConfig.s.sol)
    IERC20 token1; // Make sure to have proper token order (alphanumeric)
    IERC20 token2; // Make sure to have proper token order (alphanumeric)

    function run() external override {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }

        // Deploy mock tokens. Remove this if using already deployed tokens and instead set the tokens above
        vm.startBroadcast(deployerPrivateKey);
        (token1, token2) = deployMockTokens();
        vm.stopBroadcast();

        // Look up configuration options from `HelperConfig.s.sol`
        HelperConfig helperConfig = new HelperConfig();
        uint256 pauseWindowDuration = helperConfig.getFactoryConfig();
        (
            string memory name,
            string memory symbol,
            TokenConfig[] memory tokenConfig
        ) = helperConfig.getPoolConfig(token1, token2);
        (
            IERC20[] memory tokens,
            uint256[] memory exactAmountsIn,
            uint256 minBptAmountOut,
            bool wethIsEth,
            bytes memory userData
        ) = helperConfig.getInitializationConfig(tokenConfig);

        vm.startBroadcast(deployerPrivateKey);
        CustomPoolFactoryExample customPoolFactory = new CustomPoolFactoryExample(
                vault,
                pauseWindowDuration
            );
        console.log("Deployed Factory Address: %s", address(customPoolFactory));

        address pool = deployPoolFromFactory(
            address(customPoolFactory),
            name,
            symbol,
            tokenConfig
        );

        initializePool(
            pool,
            tokens,
            exactAmountsIn,
            minBptAmountOut,
            wethIsEth,
            userData
        );
        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }
}
