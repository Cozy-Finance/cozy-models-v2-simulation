// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "src/CostModelDynamicLevel.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

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
    /// This address is then cached inside the isDeployed mapping. See CostModelDynamicLevel
    /// constructor for more info about the input parameters.
    /// @return model_ which has an address that is deterministic with the input parameters.
    function deployModel(
        uint256 uLow_,
        uint256 uHigh_,
        uint256 costFactorAtZeroUtilization_,
        uint256 costFactorAtFullUtilization_,
        uint256 costFactorInOptimalZone_,
        uint256 optimalZoneRate_
    ) external returns (CostModelDynamicLevel model_) {
        model_ = new CostModelDynamicLevel{salt: DEFAULT_SALT}({
          uLow_: uLow_,
          uHigh_: uHigh_,
          costFactorAtZeroUtilization_: costFactorAtZeroUtilization_,
          costFactorAtFullUtilization_: costFactorAtFullUtilization_,
          costFactorInOptimalZone_: costFactorInOptimalZone_,
          optimalZoneRate_: optimalZoneRate_
        }
    );
        isDeployed[address(model_)] = true;

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

    /// @return The address where the model is deployed, or address(0) if it isn't deployed.
    function getModel(
        uint256 uLow_,
        uint256 uHigh_,
        uint256 costFactorAtZeroUtilization_,
        uint256 costFactorAtFullUtilization_,
        uint256 costFactorInOptimalZone_,
        uint256 optimalZoneRate_
    ) external view returns (address) {
        bytes memory costModelConstructorArgs_ = abi.encode(
            uLow_,
            uHigh_,
            costFactorAtZeroUtilization_,
            costFactorAtFullUtilization_,
            costFactorInOptimalZone_,
            optimalZoneRate_
        );

        address addr_ = Create2.computeCreate2Address(
            type(CostModelDynamicLevel).creationCode, costModelConstructorArgs_, address(this), DEFAULT_SALT
        );

        return isDeployed[addr_] ? addr_ : address(0);
    }
}
