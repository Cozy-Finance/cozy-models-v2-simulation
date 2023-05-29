// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "contracts/CostModelDynamicLevel.sol";
import "contracts/abstract/BaseModelFactory.sol";
import "contracts/lib/Create2.sol";

/**
 * @notice The factory for deploying a CostModelDynamicLevel contract.
 */
contract CostModelDynamicLevelFactory is BaseModelFactory {
  /// @notice Event that indicates a CostModelDynamicLevel has been deployed.
  event DeployedCostModelDynamicLevel(
    address indexed costModel,
    uint256 uLow,
    uint256 uHigh,
    uint256 costFactorAtZeroUtilization,
    uint256 costFactorAtFullUtilization,
    uint256 costFactorInOptimalZone,
    uint256 optimalZoneRate
  );

  /// @notice Deploys a CostModelDynamicLevel contract and emits a
  /// DeployedCostModelDynamicLevel event that indicates what the params from the deployment are.
  /// @return model_ which has an address.
  function deployModel(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 optimalZoneRate_
  ) external returns (CostModelDynamicLevel model_) {
    model_ = new CostModelDynamicLevel({
          uLow_: uLow_,
          uHigh_: uHigh_,
          costFactorAtZeroUtilization_: costFactorAtZeroUtilization_,
          costFactorAtFullUtilization_: costFactorAtFullUtilization_,
          costFactorInOptimalZone_: costFactorInOptimalZone_,
          optimalZoneRate_: optimalZoneRate_
        }
    );
    emit DeployedCostModelDynamicLevel(
      address(model_),
      uLow_,
      uHigh_,
      costFactorAtZeroUtilization_,
      costFactorAtFullUtilization_,
      costFactorInOptimalZone_,
      optimalZoneRate_
      );
  }
}
