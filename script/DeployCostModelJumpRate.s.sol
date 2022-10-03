// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "script/ScriptUtils.sol";
import "src/CostModelJumpRateFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys a CostModelJumpRate contract.
  * Before executing, the input json file `script/input/<chain-id>/deploy-cost-model-jump-rate-<test or production>.json`
  * should be reviewed.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployCostModelJumpRate.s.sol \
  *   --sig "run(string)" "deploy-cost-model-jump-rate-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast a transaction.
  * forge script script/DeployCostModelJumpRate.s.sol \
  *   --sig "run(string)" "deploy-cost-model-jump-rate-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployCostModelJumpRate is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // Note: The attributes in this struct must be in alphabetical order due to `parseJson` limitations.
  struct CostModelMetadata {
    uint256 cancellationPenalty; // Penalty to cancel
    uint256 costFactorAtFullUtilization; // Fee at full utilization
    uint256 costFactorAtKinkUtilization; // Fee at kink utilization
    uint256 costFactorAtZeroUtilization; // Fee at no utilization
    uint256 kink;
  }

  CostModelJumpRateFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    factory = CostModelJumpRateFactory(_json.readAddress(".factory"));

    CostModelMetadata memory _metadata = abi.decode(_json.parseRaw(".metadata"), (CostModelMetadata));

    console2.log("Deploying CostModelJumpRate...");
    console2.log("    factory", address(factory));
    console2.log("    kink", _metadata.kink);
    console2.log("    costFactorAtZeroUtilization", _metadata.costFactorAtZeroUtilization);
    console2.log("    costFactorAtKinkUtilization", _metadata.costFactorAtKinkUtilization);
    console2.log("    costFactorAtFullUtilization", _metadata.costFactorAtFullUtilization);
    console2.log("    cancellationPenalty", _metadata.cancellationPenalty);

    address _availableModel = factory.getModel(
      _metadata.kink,
      _metadata.costFactorAtZeroUtilization,
      _metadata.costFactorAtKinkUtilization,
      _metadata.costFactorAtFullUtilization,
      _metadata.cancellationPenalty
    );

    if (_availableModel == address(0)) {
      vm.broadcast();
      _availableModel = address(factory.deployModel(
        _metadata.kink,
        _metadata.costFactorAtZeroUtilization,
        _metadata.costFactorAtKinkUtilization,
        _metadata.costFactorAtFullUtilization,
        _metadata.cancellationPenalty
      ));
      console2.log("New CostModelJumpRate deployed");
    } else {
      // A CostModelJumpRate exactly like the one you wanted already exists!
      // Since models can be re-used, there's no need to deploy a new one.
      console2.log("Found existing CostModelJumpRate with specified configs.");
    }

    console2.log(
      "Your CostModelJumpRate is available at this address:",
      _availableModel
    );
  }
}
