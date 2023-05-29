// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "script/ScriptUtils.sol";
import "contracts/CostModelDynamicLevelFactory.sol";

/**
 * @notice Purpose: Local deploy, testing, and production.
 *
 * This script deploys a CostModelDynamicLevel contract.
 * Before executing, the input json file `script/input/<chain-id>/deploy-cost-model-dynamic-level-<test or
 * production>.json`
 * should be reviewed.
 *
 * To run this script:
 *
 * ```sh
 * # Start anvil, forking from the current state of the desired chain.
 * anvil --fork-url $OPTIMISM_RPC_URL
 *
 * # In a separate terminal, perform a dry run the script.
 * forge script script/DeployCostModelDynamicLevel.s.sol \
 *   --sig "run(string)" "deploy-cost-model-dynamic-level-<test or production>"
 *   --rpc-url "http://127.0.0.1:8545" \
 *   -vvvv
 *
 * # Or, to broadcast a transaction.
 * forge script script/DeployCostModelDynamicLevel.s.sol \
 *   --sig "run(string)" "deploy-cost-model-dynamic-level-<test or production>"
 *   --rpc-url "http://127.0.0.1:8545" \
 *   --private-key $OWNER_PRIVATE_KEY \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployCostModelDynamicLevel is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // Note: The attributes in this struct must be in alphabetical order due to `parseJson` limitations.
  struct CostModelMetadata {
    uint256 costFactorAtFullUtilization;
    uint256 costFactorAtZeroUtilization;
    uint256 costFactorInOptimalZone;
    uint256 optimalZoneRate;
    uint256 uHigh;
    uint256 uLow;
  }

  CostModelDynamicLevelFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory filename_) public {
    string memory json_ = readInput(filename_);

    factory = CostModelDynamicLevelFactory(json_.readAddress(".factory"));

    CostModelMetadata memory metadata_ = abi.decode(json_.parseRaw(".metadata"), (CostModelMetadata));

    console2.log("Deploying CostModelDynamicLevel...");
    console2.log("    factory", address(factory));
    console2.log("    uLow", metadata_.uLow);
    console2.log("    uHigh", metadata_.uHigh);
    console2.log("    costFactorAtZeroUtilization", metadata_.costFactorAtZeroUtilization);
    console2.log("    costFactorAtFullUtilization", metadata_.costFactorAtFullUtilization);
    console2.log("    costFactorInOptimalZone", metadata_.costFactorInOptimalZone);
    console2.log("    optimalZoneRate", metadata_.optimalZoneRate);

    vm.broadcast();
    address deployedModel_ = address(
      factory.deployModel(
        metadata_.uLow,
        metadata_.uHigh,
        metadata_.costFactorAtZeroUtilization,
        metadata_.costFactorAtFullUtilization,
        metadata_.costFactorInOptimalZone,
        metadata_.optimalZoneRate
      )
    );
    console2.log("New CostModelDynamicLevel deployed");
    console2.log("Your CostModelDynamicLevel is available at this address:", deployedModel_);
  }
}
