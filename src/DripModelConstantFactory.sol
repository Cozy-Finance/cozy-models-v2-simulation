// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/DripModelConstant.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

/**
 * @notice The factory for deploying a DripModelConstant contract.
 */
contract DripModelConstantFactory is BaseModelFactory {

  /// @notice Event that indicates a DripModelConstant has been deployed.
  event DeployedDripModelConstant(
    address indexed costModel,
    uint256 dripRatePerSecond
  );

  /// @notice Deploys a DripModelConstant contract and emits a DeployedDripModelConstant event 
  /// that indicates what the params from the deployment are. This address is then cached inside 
  /// the isDeployed mapping. 
  /// @return _model which has an address that is deterministic with the input _dripRatePerSecond.
  function deployModel(uint256 _dripRatePerSecond) external returns (DripModelConstant _model) {

    _model = new DripModelConstant{salt: DEFAULT_SALT}(_dripRatePerSecond);
    isDeployed[address(_model)] = true;

    emit DeployedDripModelConstant(address(_model), _dripRatePerSecond);
  }

  /// @return The address where the model is deployed, or address(0) if it isn't deployed.
  function getModel(uint256 _dripRatePerSecond) external view returns (address) {
    bytes memory _dripModelConstructorArgs = abi.encode(
      _dripRatePerSecond
    );

    address _addr = Create2.computeCreate2Address(
      type(DripModelConstant).creationCode, 
      _dripModelConstructorArgs,
      address(this),
      DEFAULT_SALT
    );

    return isDeployed[_addr] ? _addr : address(0);
  }
}
