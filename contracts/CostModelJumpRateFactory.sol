// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "./CostModelJumpRate.sol";
import "./abstract/BaseModelFactory.sol";
import "./lib/Create2.sol";

/**
 * @notice The factory for deploying a CostModelJumpRate contract.
 */
contract CostModelJumpRateFactory is BaseModelFactory {
  /// @notice Event that indicates a CostModelJumpRate has been deployed.
  event DeployedCostModelJumpRate(
    address indexed costModel,
    uint256 kink,
    uint256 costFactorAtZeroUtilization,
    uint256 costFactorAtKinkUtilization,
    uint256 costFactorAtFullUtilization
  );

  /// @notice Deploys a CostModelJumpRate contract and emits a
  /// DeployedCostModelJumpRate event that indicates what the params from the deployment are.
  /// This address is then cached inside the isDeployed mapping. See CostModelJumpRate
  /// constructor for more info about the input parameters.
  /// @return _model which has an address that is deterministic with the input parameters.
  function deployModel(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization
  ) external returns (CostModelJumpRate _model) {
    _model = new CostModelJumpRate{salt: DEFAULT_SALT}(
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization
    );
    isDeployed[address(_model)] = true;

    emit DeployedCostModelJumpRate(
      address(_model), _kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization
      );
  }

  /// @return The address where the model is deployed, or address(0) if it isn't deployed.
  function getModel(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization
  ) external view returns (address) {
    bytes memory _costModelConstructorArgs =
      abi.encode(_kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization);

    address _addr = Create2.computeCreate2Address(
      type(CostModelJumpRate).creationCode, _costModelConstructorArgs, address(this), DEFAULT_SALT
    );

    return isDeployed[_addr] ? _addr : address(0);
  }
}
