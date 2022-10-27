// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/DripDecayModelConstant.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

/**
 * @notice The factory for deploying a DripDecayModelConstant contract.
 */
contract DripDecayModelConstantFactory is BaseModelFactory {

  /// @notice Event that indicates a DripDecayModelConstant has been deployed.
  event DeployedDripDecayModelConstant(
    address indexed costModel,
    uint256 ratePerSecond
  );

  /// @notice Deploys a DripDecayModelConstant contract and emits a DeployedDripDecayModelConstant event that
  /// indicates what the params from the deployment are. This address is then cached inside the
  /// isDeployed mapping.
  /// @return _model which has an address that is deterministic with the input _ratePerSecond.
  function deployModel(uint256 _ratePerSecond) external returns (DripDecayModelConstant _model) {
    _model = new DripDecayModelConstant{salt: DEFAULT_SALT}(_ratePerSecond);
    isDeployed[address(_model)] = true;

    emit DeployedDripDecayModelConstant(address(_model), _ratePerSecond);
  }

  /// @return The address where the model is deployed, or address(0) if it isn't deployed.
  function getModel(uint256 _ratePerSecond) external view returns (address) {
    bytes memory _decayModelConstructorArgs = abi.encode(
      _ratePerSecond
    );

    address _addr = Create2.computeCreate2Address(
      type(DripDecayModelConstant).creationCode,
      _decayModelConstructorArgs,
      address(this),
      DEFAULT_SALT
    );

    return isDeployed[_addr] ? _addr : address(0);
  }
}
