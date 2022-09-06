// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

library Create2 {
  /// @notice Computes the address that would result from a CREATE2 call for a contract according
  /// to the spec in https://eips.ethereum.org/EIPS/eip-1014
  /// @return The CREATE2 address as computed using the params.
  /// @param _creationCode The creation code bytes of the specified contract.
  /// @param _constructorArgs The abi encoded constructor args.
  /// @param _deployer The address of the deployer of the contract.
  /// @param _salt The salt used to compute the create2 address.
  function computeCreate2Address(    
    bytes memory _creationCode,
    bytes memory _constructorArgs,
    address _deployer,
    bytes32 _salt
  ) internal pure returns (address) {
    bytes32 _bytecodeHash = keccak256(bytes.concat(_creationCode, _constructorArgs));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(_deployer), _salt, _bytecodeHash));
    return address(uint160(uint256(_data)));
  }
}
