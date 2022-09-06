// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/DecayModelConstant.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

/**
 * @notice The factory for deploying a DecayModelConstant contract.
 */
contract DecayModelConstantFactory is BaseModelFactory {

  /// @notice Event that indicates a DecayModelConstant has been deployed.
  event DeployedDecayModelConstant(
    address indexed costModel,
    uint256 decayRatePerSecond
  );

  /// @notice Deploys a DecayModelConstant contract and emits a DeployedDecayModelConstant event that 
  /// indicates what the params from the deployment are. This address is then cached inside the 
  /// isDeployed mapping. 
  /// @return _model which has an address that is deterministic with the input _decayRatePerSecond.
  function deployModel(uint256 _decayRatePerSecond) external returns (DecayModelConstant _model) {

    _model = new DecayModelConstant{salt: DEFAULT_SALT}(_decayRatePerSecond);
    isDeployed[address(_model)] = true;

    emit DeployedDecayModelConstant(address(_model), _decayRatePerSecond);
  }

  /// @return The address where the model is deployed, or address(0) if it isn't deployed.
  function getModel(uint256 _decayRatePerSecond) external view returns (address) {
    bytes memory _decayModelConstructorArgs = abi.encode(
      _decayRatePerSecond
    );

    address _addr = Create2.computeCreate2Address(
      type(DecayModelConstant).creationCode, 
      _decayModelConstructorArgs,
      address(this),
      DEFAULT_SALT
    );

    return isDeployed[_addr] ? _addr : address(0);
  }
}
