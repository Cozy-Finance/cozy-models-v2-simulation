// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/DecayModelConstantFactory.sol";
import "src/lib/Create2.sol";
import "forge-std/Test.sol";

contract DecayModelConstantFactoryTest is Test, DecayModelConstantFactory {

  DecayModelConstantFactory factory;

  function setUp() public {
    factory = new DecayModelConstantFactory();
  }

  function test_deployModelAndVerifyAvailable() public {
    testFuzz_deployModelAndVerifyAvailable(100);
  }

  function testFuzz_deployModelAndVerifyAvailable(uint256 _decayRatePerSecond) public {
    _decayRatePerSecond = bound(_decayRatePerSecond, 0, type(uint256).max);

    assertEq(factory.getModel(_decayRatePerSecond), address(0));

    bytes memory _decayModelConstructorArgs = abi.encode(_decayRatePerSecond);

    address _addr = Create2.computeCreate2Address(
      type(DecayModelConstant).creationCode, 
      _decayModelConstructorArgs,
      address(factory),
      keccak256("0")
    );

    vm.expectEmit(true, false, false, true);
    emit DeployedDecayModelConstant(_addr, _decayRatePerSecond);
    address _result = address(factory.deployModel(_decayRatePerSecond));
    assertEq(_result, factory.getModel(_decayRatePerSecond));

    // Trying to deploy again should result in revert
    vm.expectRevert();
    factory.deployModel(_decayRatePerSecond);
  }
}
