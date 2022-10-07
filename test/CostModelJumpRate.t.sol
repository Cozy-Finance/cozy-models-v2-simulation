// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import "solmate/utils/FixedPointMathLib.sol";
import "cozy-v2-interfaces/interfaces/ICostModel.sol";
import "test/utils/MockCostModelJumpRate.sol";

contract CostModelSetup is Test {
  using FixedPointMathLib for uint256;

  MockCostModelJumpRate costModel;

  uint256 public constant CANCELLATION_PENALTY = 0.1e18;

  function setUp() public virtual {
    costModel = new MockCostModelJumpRate(
      0.8e18, // kink at 80% utilization
      0.0e18, // 0% fee at no utilization
      0.2e18, // 20% fee at kink utilization
      0.5e18, // 50% fee at full utilization
      CANCELLATION_PENALTY // charge a 10% penalty to cancel
    );
  }
}

contract CostModelDeploy is CostModelSetup {
  function testFuzz_ConstructorRevertsWhenArgumentsAreTooHigh(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization,
    uint256 _cancellationPenalty
  ) public {
    uint256 _oneHundredPercent = 1e18;
    vm.assume(
      _kink > _oneHundredPercent
      || _costFactorAtZeroUtilization > _oneHundredPercent
      || _costFactorAtKinkUtilization > _oneHundredPercent
      || _costFactorAtFullUtilization > _oneHundredPercent
      || _cancellationPenalty > _oneHundredPercent
    );

    vm.expectRevert(CostModelJumpRate.InvalidConfiguration.selector);
    new MockCostModelJumpRate(
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization,
      _cancellationPenalty
    );
  }
}

contract CostFactorTest is CostModelSetup {
  function testFuzz_CostFactorRevertsIfNewUtilizationIsLowerThanOld(uint256 oldUtilization, uint256 newUtilization) public {
    vm.assume(newUtilization != oldUtilization);
    if (newUtilization > oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
    vm.expectRevert(CostModelJumpRate.InvalidUtilization.selector);
    costModel.costFactor(oldUtilization, newUtilization);
  }

  function testFuzz_CostFactorRevertsIfNewUtilizationIsGreaterThan100(uint256 oldUtilization, uint256 newUtilization) public {
    vm.assume(newUtilization > 1e18);
    vm.expectRevert(CostModelJumpRate.InvalidUtilization.selector);
    costModel.costFactor(oldUtilization, newUtilization);
  }

  function test_CostFactorOverSpecificUtilizationIntervals() public {
    // All below kink.
    assertEq(costModel.costFactor(0.0e18, 0.2e18), 0.025e18);  // 0%-20% util ==> 2.5%
    assertEq(costModel.costFactor(0.0e18, 0.5e18), 0.0625e18); // 0%-50% util ==> 6.25%
    assertEq(costModel.costFactor(0.1e18, 0.2e18), 0.0375e18); // 10%-20% util ==> 3.75%

    // Span accross kink.
    assertEq(costModel.costFactor(0.5e18, 0.9e18), 0.190625e18); // 50-90% util ==> 19.06%
    assertEq(costModel.costFactor(0.0e18, 1.0e18), 0.15e18);     // 0-100% util ==> 15%

    // Kink in one or more argument.
    assertEq(costModel.costFactor(0.4e18, 0.8e18), 0.15e18);  // 40-80% util ==> 15%
    assertEq(costModel.costFactor(0.8e18, 1.0e18), 0.35e18);  // 80-100% util ==> 35%
    assertEq(costModel.costFactor(0.0e18, 0.8e18), 0.1e18);   // 0%-80% util ==> 10%
    assertEq(costModel.costFactor(0.2e18, 0.8e18), 0.125e18); // 20%-80% util ==> 12.5%

    // All above kink.
    assertEq(costModel.costFactor(0.9e18, 1.0e18), 0.425e18); // 90%-100% util ==> 42.5%
  }

  function test_CostFactorWhenIntervalIsZero() public {
    // At the defined points.
    assertEq(costModel.costFactor(0.0e18, 0.0e18), 0.0e18);
    assertEq(costModel.costFactor(0.8e18, 0.8e18), 0.2e18);
    assertEq(costModel.costFactor(1.0e18, 1.0e18), 0.5e18);

    // At arbitrary points.
    assertEq(costModel.costFactor(0.05e18, 0.05e18), 0.0125e18);
    assertEq(costModel.costFactor(0.1e18, 0.1e18), 0.025e18);
    assertEq(costModel.costFactor(0.2e18, 0.2e18), 0.05e18);
    assertEq(costModel.costFactor(0.4e18, 0.4e18), 0.1e18);
    assertEq(costModel.costFactor(0.9e18, 0.9e18), 0.35e18);
    assertEq(costModel.costFactor(0.95e18, 0.95e18), 0.425e18);
  }

  function testFuzz_CostFactorOverRandomIntervals(
    uint256 intervalLowPoint,
    uint256 intervalMidPoint,
    uint256 intervalHighPoint,
    uint256 totalProtection
  ) public {
    intervalHighPoint = bound(intervalHighPoint, 0.000003e18, 1e18); // 0.0003% is just a very low high-interval
    intervalMidPoint = bound(intervalMidPoint, 2e12, intervalHighPoint);
    intervalLowPoint = bound(intervalLowPoint, 0, intervalMidPoint);

    totalProtection = bound(totalProtection, 1e10, type(uint128).max);

    uint256 costFactorA = costModel.costFactor(intervalLowPoint, intervalMidPoint);
    uint256 costFactorB = costModel.costFactor(intervalMidPoint, intervalHighPoint);

    uint256 feeAmountTwoIntervals = (
    //  |<----------------------- feeAmountA * 1e36 ----------------------->|
    //  |<------------ protectionAmountA * 1e18 ------------->|
        (intervalMidPoint - intervalLowPoint) * totalProtection * costFactorA
    //  |<----------------------- feeAmountN * 1e36 ----------------------->|
    //  |<------------ protectionAmountB * 1e18 ------------->|
      + (intervalHighPoint - intervalMidPoint) * totalProtection * costFactorB
    ) / 1e36;

    // Now do the same thing but over a single interval.
    uint256 protectionAmountOneInterval = (intervalHighPoint - intervalLowPoint) * totalProtection / 1e18;
    uint256 costFactorOneInterval = costModel.costFactor(intervalLowPoint, intervalHighPoint);
    uint256 feeAmountOneInterval = protectionAmountOneInterval * costFactorOneInterval / 1e18;

    // The fees will differ slightly because of integer division rounding.
    assertApproxEqRel(feeAmountOneInterval, feeAmountTwoIntervals, 0.001e18);
  }

  function test_CostFactorWorksWhenZeroUtilizationCostIsGreaterThanZero() public {
    costModel = new MockCostModelJumpRate(
      0.55e18, // kink at 55% utilization
      0.15e18, // 15% fee at no utilization
      0.40e18, // 40% fee at kink utilization
      0.45e18, // 45% fee at full utilization
      CANCELLATION_PENALTY // charge a 10% penalty to cancel
    );

    /// There are two different areas under this cost factor curve. They are:
    ///
    ///  Area A:
    ///     ^
    ///     |
    ///  F  |     (kink)                         ___
    ///  a  |    /|                           /|  |
    ///  c  |  /  |                         /  | 0.25
    ///  t  |/    |                 ==    /....| _|_
    ///  o  |  A  |                      |     |  |
    ///  r  |     |                      |     | 0.15
    ///     `-----|------------>         `-----' _|_
    ///         Utilization %              0.55
    ///
    ///  Area A = triangle      + rectangle
    ///  Area A = (0.55*0.25)/2 + (0.55 * 0.15)
    ///  Area A = 0.15125

    ///  Area B:
    ///     ^
    ///     |                                    ___
    ///     |          /|                     /|  |
    ///     |         / |                    / |  |
    ///  F  |       /   |                  /   | 0.05
    ///  a  |...../     |           ==   /.....| _|_
    ///  c  |     |  B  |                |     |  |
    ///  t  |     |     |                |     |  |
    ///  o  |     |     |                |     | 0.4
    ///  r  |     |     |                |     |  |
    ///     `-----|-----|------->        `-----' _|_
    ///         Utilization %              0.45
    ///
    ///  Area B = triangle      + rectangle
    ///  Area B = (0.05*0.45)/2 + (0.4 * 0.45)
    ///  Area B = 0.19125
    ///
    ///  Total = Area A + Area B
    ///  Total = 0.15125 + 0.19125
    ///  Total = 0.3425
    assertApproxEqRel(costModel.costFactor(0.0e18, 1.0e18), 0.3425e18, 0.00000001e18);
  }

}

contract RefundFactorTest is CostModelSetup {
  function testFuzz_RefundFactorRevertsIfOldUtilizationIsLowerThanNew(uint256 oldUtilization, uint256 newUtilization) public {
    vm.assume(newUtilization != oldUtilization);
    if (newUtilization < oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
    vm.expectRevert(CostModelJumpRate.InvalidUtilization.selector);
    costModel.refundFactor(oldUtilization, newUtilization);
  }

  function testFuzz_RefundFactorRevertsIfOldUtilizationIsGreaterThan100(uint256 oldUtilization, uint256 newUtilization) public {
    vm.assume(oldUtilization > 1e18);
    vm.expectRevert(CostModelJumpRate.InvalidUtilization.selector);
    costModel.refundFactor(oldUtilization, newUtilization);
  }

  // The refund factor should return the percentage that the interval
  // constitutes of the area under the utilized portion of the curve.
  function test_RefundFactorOverSpecificUtilizationIntervals() public {
    // See test_AreaUnderCurveWhenIntervalIsNonZero for the source of the area calculations.
    // Formula is: area-within-interval / total-utilized-area * (1 - penalty)
    // Where:
    //   area-within-interval = B, i.e. the portion of utilization being canceled
    //   total-utilized-area = A+B
    //
    //     ^                        /
    //     |                      /
    //     |                    /
    //  R  |                  / |
    //  a  |                /   |
    //  t  |             _-`    |
    //  e  |          _-`       |
    //     |       _-`  |       |
    //     |    _-`     |   B   |
    //     | _-`    A   |       |
    //     `----------------------------->
    //           Utilization %

    // All below kink.
    assertApproxEqAbs(costModel.refundFactor(0.2e18, 0.0e18), 0.9e18, 1); // all of the fees, less the penalty
    assertApproxEqAbs(costModel.refundFactor(0.5e18, 0.0e18), 0.9e18, 1); // all of the fees, less the penalty
    assertApproxEqAbs(costModel.refundFactor(0.2e18, 0.1e18), 0.675e18, 1); // 0.00375 / 0.005 * 0.9

    // Span accross kink.
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.5e18), 0.638372093e18, 1e10); // 0.07625 / 0.1075 * 0.9
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.0e18), 0.9e18, 1); // all of the fees, less the penalty

    // Kink in one or more argument.
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.8e18), 0.42e18, 1); // 0.07 / 0.15 * 0.9
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.8e18), 0.230232558e18, 1e10); // (0.15 - 0.0425 - 0.08) / (0.15 - 0.0425) * 0.9
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.4e18), 0.675e18, 1); // 0.06 / 0.08 * 0.9
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.2e18), 0.84375e18, 1); // 0.075 / 0.08 * 0.9
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.0e18), 0.9e18, 1); // all of the fees, less the penalty

    // All above kink.
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.9e18), 0.255e18, 1); // 0.0425 / 0.15 * 0.9
  }

  function test_RefundFactorWhenIntervalIsZero(uint256 _utilization) public {
    _utilization = bound(_utilization, 0, 1.0e18);
    assertEq(costModel.refundFactor(_utilization, _utilization), 0);
  }
}

contract AreaUnderCurveTest is CostModelSetup {
  function testFuzz_AreaUnderCurveWhenIntervalIsZero(uint256 _utilization) public {
    _utilization = bound(_utilization, 0, 1.0e18);
    assertEq(costModel.areaUnderCurve(_utilization, _utilization), 0);
  }

  function test_AreaUnderCurveWhenIntervalIsNonZero() public {
    // The base unit is e36 b/c we're multiplying two WADs.

    // All below kink.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.2e18), 0.005e36); // 0.5 * 0.2 * 0.2(0.25)
    assertEq(costModel.areaUnderCurve(0.0e18, 0.5e18), 0.03125e36); // 0.5 * 0.5 * 0.5(0.25)
    assertEq(costModel.areaUnderCurve(0.1e18, 0.2e18), 0.00375e36); // 1.5 * (0.1 * 0.1 * 0.25)

    // Span accross kink.
    // (0.3 * 0.25 * 0.5) + (0.5 * 0.3 * 0.25 * 0.3) + (0.1 * 0.2) + (0.5 * 0.1 * 1.5 * 0.1)
    assertEq(costModel.areaUnderCurve(0.5e18, 0.9e18), 0.07625e36); // Calculation above ^^
    assertEq(costModel.areaUnderCurve(0.0e18, 1.0e18), 0.15e36); // (0.5 * 0.8 * 0.2) + (0.2 * 0.2) + (0.5 * 0.2 * 0.3)

    // Kink in one or more argument.
    assertEq(costModel.areaUnderCurve(0.4e18, 0.8e18), 0.06e36); // 1.5 * (0.4 * 0.25 * 0.4)
    assertEq(costModel.areaUnderCurve(0.8e18, 1.0e18), 0.07e36); // (0.2 * 0.2) + (0.5 * 0.2 * 1.5 * 0.2)
    assertEq(costModel.areaUnderCurve(0.0e18, 0.8e18), 0.08e36); // 0.5 * 0.8 * 0.2
    assertEq(costModel.areaUnderCurve(0.2e18, 0.8e18), 0.075e36); // (0.5 * 0.6 * (0.2 - 0.2 * 0.25)) + (0.6 * 0.2 * 0.25)

    // All above kink.
    assertEq(costModel.areaUnderCurve(0.9e18, 1.0e18), 0.0425e36); // (0.5 * 0.1 * 1.5 * 0.1) + (0.1 * (1.5 * 0.1 + 0.2))
  }

  function test_AreaUnderCurveForNonStandardJumpRate() public {
    costModel = new MockCostModelJumpRate(
      0.3e18, // kink at 30% utilization
      0.1e18, // 10% fee at no utilization
      0.4e18, // 40% fee at kink utilization
      0.75e18, // 75% fee at full utilization
      CANCELLATION_PENALTY // charge a 10% penalty to cancel
    );

    // Slope below kink = 0.3/0.3 = 1
    // Slope above kink = 0.35/0.7 = 0.5

    // Zero utilization.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.0e18), 0);
    assertEq(costModel.areaUnderCurve(0.1e18, 0.1e18), 0);
    assertEq(costModel.areaUnderCurve(0.3e18, 0.3e18), 0);
    assertEq(costModel.areaUnderCurve(0.8e18, 0.8e18), 0);
    assertEq(costModel.areaUnderCurve(1.0e18, 1.0e18), 0);

    // The base unit is e36 b/c we're multiplying two WADs.

    // All below kink.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.1e18), 0.015e36); // (0.1 * 0.1) + (0.5 * 0.1 * 0.1)
    assertEq(costModel.areaUnderCurve(0.1e18, 0.15e18), 0.01125e36); // (0.05 * (0.1 + 0.1)) + (0.5 * 0.05 * 0.05)

    // Span accross kink.
    // (0.1 * (0.1 + 0.2)) + (0.5 * 0.1 * 0.1) + (0.4 * 0.2) + (0.5 * 0.2 * 0.2 * 0.5))
    assertEq(costModel.areaUnderCurve(0.2e18, 0.5e18), 0.125e36); // Calc above ^^.
    // (0.3 * 0.1) + (0.5 * 0.3 * (0.4 - 0.1)) + (0.7 * 0.4) + (0.5 * 0.7 * (0.75 - 0.4))
    assertEq(costModel.areaUnderCurve(0.0e18, 1.0e18), 0.4775e36); // Calc above ^^.

    // Kink in one or more argument.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.3e18), 0.075e36); // (0.1 * 0.3) + (0.5 * 0.3 * (0.4 - 0.1))
    assertEq(costModel.areaUnderCurve(0.3e18, 1.0e18), 0.4025e36); // (0.7 * 0.4) + (0.5 * 0.7 * (0.75 - 0.4))
    assertEq(costModel.areaUnderCurve(0.2e18, 0.3e18), 0.035e36); // (0.1 * (0.1 + 0.2)) + (0.5 * 0.1 * 0.1)
    assertEq(costModel.areaUnderCurve(0.3e18, 0.8e18), 0.2625e36); // (0.4 * 0.5) + (0.5 * 0.5 * (0.5 * 0.5))

    // All above kink.
    assertEq(costModel.areaUnderCurve(0.9e18, 1.0e18), 0.0725e36); // (0.1 * (0.75 - 0.5*0.1)) + (0.5 * 0.1 * 0.1 * 0.5)
    assertEq(costModel.areaUnderCurve(0.45e18, 0.6e18), 0.076875e36); // (0.15 * (0.4 + 0.15 * 0.5)) + (0.5 * 0.15 * 0.15 * 0.5)
  }
}
