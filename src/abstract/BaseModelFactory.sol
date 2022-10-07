// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

/**
 * @notice Base class for model factories.
 */
abstract contract BaseModelFactory {

  /// @dev We have a default salt for computing the resulting address of a create2 call. 
  /// This is ok due to a combination of two reasons: 
  /// (1) for a given configuration, only a single instance of that model needs to exist, and
  /// (2) models have constructor args and therefore each configuration has a different initcode hash. 
  /// As a result, the differing initcode is sufficient to make sure each model 
  /// is at a unique address and the salt is unnecessary here.
  bytes32 internal constant DEFAULT_SALT = keccak256("0");

  /// @notice The set of all Models that have been deployed from this factory. 
  /// The created Models should always have addresses that are deterministic with
  /// the model creation parameters, so if the model exists then it will be in this mapping. 
  /// Use getModel(/*params*/) to check if the model exists in the mapping and return 
  /// the address directly.
  mapping (address => bool) public isDeployed;
}
