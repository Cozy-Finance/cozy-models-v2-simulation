// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/DripModelConstantFactory.sol";
import "src/lib/Create2.sol";
import "forge-std/Test.sol";

contract DripModelConstantFactoryTest is Test, DripModelConstantFactory {

  DripModelConstantFactory factory;

  function setUp() public {
    factory = new DripModelConstantFactory();
  }

  function test_deployModelAndVerifyAvailable() public {
    testFuzz_deployModelAndVerifyAvailable(100);
  }

  function testFuzz_deployModelAndVerifyAvailable(uint256 _dripRatePerSecond) public {
    _dripRatePerSecond = bound(_dripRatePerSecond, 0, type(uint256).max);

    assertEq(factory.getModel(_dripRatePerSecond), address(0));

    bytes memory _dripModelConstructorArgs = abi.encode(
      _dripRatePerSecond
    );

    address _addr = Create2.computeCreate2Address(
      type(DripModelConstant).creationCode, 
      _dripModelConstructorArgs,
      address(factory),
      keccak256("0")
    );

    vm.expectEmit(true, false, false, true);
    emit DeployedDripModelConstant(_addr, _dripRatePerSecond);
    address _result = address(factory.deployModel(_dripRatePerSecond));
    assertEq(_result, factory.getModel(_dripRatePerSecond));

    // Trying to deploy again should result in revert
    vm.expectRevert();
    factory.deployModel(_dripRatePerSecond);
  }
}
