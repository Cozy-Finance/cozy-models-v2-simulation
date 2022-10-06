// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/CostModelJumpRate.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

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
    uint256 costFactorAtFullUtilization,
    uint256 cancellationPenalty
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
    uint256 _costFactorAtFullUtilization,
    uint256 _cancellationPenalty
  ) external returns (CostModelJumpRate _model) {

    _model = new CostModelJumpRate{salt: DEFAULT_SALT}(
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization,
      _cancellationPenalty
    );
    isDeployed[address(_model)] = true;

    emit DeployedCostModelJumpRate(
      address(_model),
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization,
      _cancellationPenalty
    );
  }

  /// @return The address where the model is deployed, or address(0) if it isn't deployed.
  function getModel(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization,
    uint256 _cancellationPenalty
  ) external view returns (address) {
    bytes memory _costModelConstructorArgs = abi.encode(
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization,
      _cancellationPenalty
    );

    address _addr = Create2.computeCreate2Address(
      type(CostModelJumpRate).creationCode, 
      _costModelConstructorArgs,
      address(this),
      DEFAULT_SALT
    );

    return isDeployed[_addr] ? _addr : address(0);
  }
}
