// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "script/ScriptUtils.sol";
import "src/DripDecayModelConstantFactory.sol";
import "solmate/utils/FixedPointMathLib.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys a DripDecayModelConstant contract.
  * Before executing, the input json file `script/input/<chain-id>/deploy-decay-model-constant-<test or production>.json`
  * should be reviewed.
  * 
  * Config Params:
  * 
  * factory: The address of the factory which will deploy the DripDecayModelConstant contract.
  * 
  * dripDecayPercentage: dripDecay percentage expressed as an 18 decimal precision uint256. For example, 
  * 25% dripDecay should be 0.25e18, or `250000000000000000` in a JSON file.
  * 
  * dripDecayPeriodInSeconds: The number of seconds in which the drip/decay takes place over. 
  * For example, one year would be 31557600.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run of the script.
  * forge script script/DeployDecayModelConstant.s.sol \
  *   --sig "run(string)" "deploy-decay-model-constant-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast a transaction.
  * forge script script/DeployDecayModelConstant.s.sol \
  *   --sig "run(string)" "deploy-decay-model-constant-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployDripDecayModelConstant is ScriptUtils {
  using stdJson for string;

  uint256 constant MAX_INT256 = uint256(type(int256).max);

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    DripDecayModelConstantFactory _factory = DripDecayModelConstantFactory(_json.readAddress(".factory"));
    uint256 _dripDecayPercentage = _json.readUint(".dripDecayPercentage");
    uint256 _dripDecayPeriodInSeconds = _json.readUint(".dripDecayPeriodInSeconds");
    uint256 _finalPercentage = 1e18 - _dripDecayPercentage;
    uint256 _dripDecayRatePerSecond = calculateDripDecayRate(_finalPercentage, 1e18, _dripDecayPeriodInSeconds);

    console2.log("Deploying DripDecayModelConstant...");
    console2.log("    factory", address(_factory));
    console2.log("    dripDecayRate percentage", _dripDecayPercentage * 100/1e18);
    console2.log("    dripDecayRatePerSecond", _dripDecayRatePerSecond);

    address _availableModel = _factory.getModel(_dripDecayRatePerSecond);

    if (_availableModel == address(0)) {
      vm.broadcast();
      _availableModel = address(_factory.deployModel(_dripDecayRatePerSecond));
      console2.log("New DripDecayModelConstant deployed");
    } else {
      // A DripDecayModelConstant exactly like the one you wanted already exists!
      // Since models can be re-used, there's no need to deploy a new one.
      console2.log("Found existing DripDecayModelConstant with specified configs.");
    }

    console2.log(
      "Your DripDecayModelConstant is available at this address:",
      _availableModel
    );
  }

  /// @dev Calculate the exponential drip/decay rate, according to   
  ///   A = P * (1 - r) ^ t
  /// where:
  ///   A is final amount.
  ///   P is principal (starting) amount.
  ///   r is the per-second drip/decay rate.
  ///   t is the number of elapsed seconds.
  /// A and p should be expressed as 18 decimal numbers, e.g to calculate the 
  /// @param _a 18 decimal precision uint256 expressing the final amount.
  /// @param _p 18 decimal precision uint256 expressing the principal. 
  /// @param _t uint256 expressing the time in seconds. 
  /// @return _r 18 decimal precision uint256 expressing the decay rate in seconds.
  function calculateDripDecayRate(uint256 _a, uint256 _p, uint256 _t) internal view returns (uint256 _r) {
    require(_a <= _p, "Final amount must be less than or equal to principal.");
    require(_a <= MAX_INT256, "_a must be smaller than type(int256).max");
    require(_p <= MAX_INT256, "_p must be smaller than type(int256).max");
    require(_t <= MAX_INT256, "_t must be smaller than type(int256).max");

    // Let 1 - r = x, then (ln(A) - ln(p))/t = ln(x)
    int256 _lnX = (FixedPointMathLib.lnWad(int256(_a)) - FixedPointMathLib.lnWad(int256(_p))) / int256(_t);
    int256 _x = FixedPointMathLib.expWad(_lnX);
    require(_x >= 0, "_x must be >= 0");
    _r = 1e18 - uint256(_x);
  }
}
