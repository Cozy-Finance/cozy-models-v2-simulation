// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "contracts/CostModelJumpRateFactory.sol";
import "contracts/CostModelDynamicLevelFactory.sol";
import "contracts/DripDecayModelConstantFactory.sol";

/**
 * @notice Purpose: Local deploy, testing, and production.
 *
 * This script deploys the Model Factory contracts.
 * Before executing, the configuration section in the script should be updated.
 *
 * To run this script:
 *
 * ```sh
 * # Start anvil, forking from the current state of the desired chain.
 * anvil --fork-url $OPTIMISM_RPC_URL
 *
 * # In a separate terminal, perform a dry run of the script.
 * forge script script/DeployModelFactories.s.sol \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   -vvvv
 *
 * # Or, to broadcast a transaction.
 * forge script script/DeployModelFactories.s.sol \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   --private-key $OWNER_PRIVATE_KEY \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployModelFactories is Script {
  /// @notice Deploys all the Model Factory contracts
  function run() public {
    console2.log("Deploying Cozy V2 Model Factories...");

    console2.log("  Deploying CostModelJumpRateFactory...");
    vm.broadcast();
    address costModelFactory = address(new CostModelJumpRateFactory());
    console2.log("  CostModelJumpRateFactory deployed,", costModelFactory);

    console2.log("  Deploying CostModelDynamicLevelFactory...");
    vm.broadcast();
    address costModelDynamicLevelFactory = address(new CostModelDynamicLevelFactory());
    console2.log("  CostModelDynamicLevelFactory deployed,", costModelDynamicLevelFactory);

    console2.log("  Deploying DripDecayModelConstantFactory...");
    vm.broadcast();
    address dripDecayModelFactory = address(new DripDecayModelConstantFactory());
    console2.log("  DripDecayModelConstantFactory deployed,", dripDecayModelFactory);

    console2.log("Finished deploying Cozy V2 Model Factories");
  }
}
