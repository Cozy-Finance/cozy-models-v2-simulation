// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "contracts/CostModelJumpRateFactory.sol";
import "contracts/lib/Create2.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";

contract CostModelJumpRateFactoryTest is Test, CostModelJumpRateFactory {
  CostModelJumpRateFactory factory;

  function setUp() public {
    factory = new CostModelJumpRateFactory();
  }

  function test_deployModelAndVerifyAvailable() public {
    testFuzz_deployModelAndVerifyAvailable(
      0.8e18, // kink at 80% utilization
      0.0e18, // 0% fee at no utilization
      0.2e18, // 20% fee at kink utilization
      0.5e18 // 50% fee at full utilization
    );
  }

  function testFuzz_deployModelAndVerifyAvailable(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization
  ) public {
    _kink = bound(_kink, 0, FixedPointMathLib.WAD);
    _costFactorAtZeroUtilization = bound(_costFactorAtZeroUtilization, 0, FixedPointMathLib.WAD);
    _costFactorAtKinkUtilization = bound(_costFactorAtKinkUtilization, 0, FixedPointMathLib.WAD);
    _costFactorAtFullUtilization = bound(_costFactorAtFullUtilization, 0, FixedPointMathLib.WAD);

    address _existingAddress =
      factory.getModel(_kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization);
    assertEq(_existingAddress, address(0));

    bytes memory _costModelConstructorArgs =
      abi.encode(_kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization);

    address _addr = Create2.computeCreate2Address(
      type(CostModelJumpRate).creationCode, _costModelConstructorArgs, address(factory), keccak256("0")
    );

    vm.expectEmit(true, false, false, true);
    emit DeployedCostModelJumpRate(
      _addr, _kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization
      );

    address _result = address(
      factory.deployModel(
        _kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization
      )
    );
    _existingAddress =
      factory.getModel(_kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization);
    assertEq(_result, _existingAddress);

    // Trying to deploy again should result in revert
    vm.expectRevert();
    factory.deployModel(_kink, _costFactorAtZeroUtilization, _costFactorAtKinkUtilization, _costFactorAtFullUtilization);
  }
}
