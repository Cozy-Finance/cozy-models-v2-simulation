// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "solmate/utils/FixedPointMathLib.sol";
import "src/interfaces/ICostModel.sol";
import "test/utils/MockCostModelJumpRate.sol";

contract CostModelSetup is Test {
  using FixedPointMathLib for uint256;

  MockCostModelJumpRate costModel;

  function setUp() public virtual {
    costModel = new MockCostModelJumpRate(
      0.8e18, // kink at 80% utilization
      0.0e18, // 0% fee at no utilization
      0.2e18, // 20% fee at kink utilization
      0.5e18 // 50% fee at full utilization
    );
  }
}

contract CostModelDeploy is CostModelSetup {
  function testFuzz_ConstructorRevertsWhenArgumentsAreTooHigh(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization
  ) public {
    uint256 _oneHundredPercent = 1e18;
    vm.assume(
      _kink > _oneHundredPercent
      || _costFactorAtZeroUtilization > _oneHundredPercent
      || _costFactorAtKinkUtilization > _oneHundredPercent
      || _costFactorAtFullUtilization > _oneHundredPercent
    );

    vm.expectRevert(CostModelJumpRate.InvalidConfiguration.selector);
    new MockCostModelJumpRate(
      _kink,
      _costFactorAtZeroUtilization,
      _costFactorAtKinkUtilization,
      _costFactorAtFullUtilization
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
      0.45e18 // 45% fee at full utilization
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

  // The refund factor should return the percentage that the interval
  // constitutes of the area under the utilized portion of the curve.
  function test_RefundFactorOverSpecificUtilizationIntervals() public {
    // See test_AreaUnderCurveWhenIntervalIsNonZero for the source of the area calculations.
    // Formula is: area-within-interval / total-utilized-area
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
    assertEq(costModel.refundFactor(0.2e18, 0.0e18), 1e18); // all of the fees
    assertEq(costModel.refundFactor(0.5e18, 0.0e18), 1e18); // all of the fees
    assertEq(costModel.refundFactor(0.2e18, 0.1e18), 0.75e18); // 0.00375 / 0.005

    // Span accross kink.
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.5e18), 0.709302325e18, 1e10); // 0.07625 / 0.1075
    assertEq(costModel.refundFactor(1.0e18, 0.0e18), 1e18); // all of the fees

    // Kink in one or more argument.
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.8e18), 0.466666666666666666e18, 1); // 0.07 / 0.15
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.8e18), 0.2558139535e18, 1e10); // (0.15 - 0.0425 - 0.08) / (0.15 - 0.0425)
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.4e18), 0.75e18, 1); // 0.06 / 0.08
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.2e18), 0.9375e18, 1); // 0.075 / 0.08
    assertEq(costModel.refundFactor(0.8e18, 0.0e18), 1e18); // all of the fees

    // All above kink.
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.9e18), 0.283333333333333333e18, 1); // 0.0425 / 0.15

    // Above 100% utilization.
    assertEq(costModel.refundFactor(1.6e18, 1.5e18), 0.184027777777777777e18);
    assertEq(costModel.refundFactor(1.6e18, 1.2e18), 0.611111111111111111e18);
    assertEq(costModel.refundFactor(1.6e18, 1e18), 0.791666666666666666e18);
    assertEq(costModel.refundFactor(1.6e18, 0.8e18), 0.888888888888888888e18);
    assertEq(costModel.refundFactor(1.6e18, 0.0e18), 1e18); // all of the fees
  }

  function test_RefundFactorWhenIntervalIsZero(uint256 _utilization) public {
    _utilization = bound(_utilization, 0, 2.0e18);
    assertEq(costModel.refundFactor(_utilization, _utilization), 0);
  }
}

contract AreaUnderCurveTest is CostModelSetup {
  function testFuzz_AreaUnderCurveWhenIntervalIsZero(uint256 _utilization) public {
    _utilization = bound(_utilization, 0, 2.0e18);
    assertEq(costModel.areaUnderCurve(_utilization, _utilization), 0);
  }

  function test_AreaUnderCurveWhenIntervalIsNonZero() public {
    // The base unit is e54 b/c we're scaling up by three WADs.

    // All below kink.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.2e18), 0.005e54); // 0.5 * 0.2 * 0.2(0.25)
    assertEq(costModel.areaUnderCurve(0.0e18, 0.5e18), 0.03125e54); // 0.5 * 0.5 * 0.5(0.25)
    assertEq(costModel.areaUnderCurve(0.1e18, 0.2e18), 0.00375e54); // 1.5 * (0.1 * 0.1 * 0.25)

    // Span accross kink.
    // (0.3 * 0.25 * 0.5) + (0.5 * 0.3 * 0.25 * 0.3) + (0.1 * 0.2) + (0.5 * 0.1 * 1.5 * 0.1)
    assertEq(costModel.areaUnderCurve(0.5e18, 0.9e18), 0.07625e54); // Calculation above ^^
    assertEq(costModel.areaUnderCurve(0.0e18, 1.0e18), 0.15e54); // (0.5 * 0.8 * 0.2) + (0.2 * 0.2) + (0.5 * 0.2 * 0.3)

    // Kink in one or more argument.
    assertEq(costModel.areaUnderCurve(0.5e18, 0.8e18), 0.04875e54); // (0.3 * 0.5 * 0.25) + (0.5 * 0.3 * 0.3 * 0.25)
    assertEq(costModel.areaUnderCurve(0.8e18, 0.9e18), 0.0275e54); // (0.2 * 0.1) + (0.5 * 0.1 * 0.1 * 1.5)
    assertEq(costModel.areaUnderCurve(0.4e18, 0.8e18), 0.06e54); // 1.5 * (0.4 * 0.25 * 0.4)
    assertEq(costModel.areaUnderCurve(0.8e18, 1.0e18), 0.07e54); // (0.2 * 0.2) + (0.5 * 0.2 * 1.5 * 0.2)
    assertEq(costModel.areaUnderCurve(0.0e18, 0.8e18), 0.08e54); // 0.5 * 0.8 * 0.2
    assertEq(costModel.areaUnderCurve(0.2e18, 0.8e18), 0.075e54); // (0.5 * 0.6 * (0.2 - 0.2 * 0.25)) + (0.6 * 0.2 * 0.25)

    // All above kink.
    assertEq(costModel.areaUnderCurve(0.9e18, 1.0e18), 0.0425e54); // (0.5 * 0.1 * 1.5 * 0.1) + (0.1 * (1.5 * 0.1 + 0.2))
  }

  function test_AreaUnderCurveForNonStandardJumpRate() public {
    costModel = new MockCostModelJumpRate(
      0.3e18, // kink at 30% utilization
      0.1e18, // 10% fee at no utilization
      0.4e18, // 40% fee at kink utilization
      0.75e18 // 75% fee at full utilization
    );

    // Slope below kink = 0.3/0.3 = 1
    // Slope above kink = 0.35/0.7 = 0.5

    // Zero utilization.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.0e18), 0);
    assertEq(costModel.areaUnderCurve(0.1e18, 0.1e18), 0);
    assertEq(costModel.areaUnderCurve(0.3e18, 0.3e18), 0);
    assertEq(costModel.areaUnderCurve(0.8e18, 0.8e18), 0);
    assertEq(costModel.areaUnderCurve(1.0e18, 1.0e18), 0);

    // The base unit is e54 b/c we're multiplying three WADs.

    // All below kink.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.1e18), 0.015e54); // (0.1 * 0.1) + (0.5 * 0.1 * 0.1)
    assertEq(costModel.areaUnderCurve(0.1e18, 0.15e18), 0.01125e54); // (0.05 * (0.1 + 0.1)) + (0.5 * 0.05 * 0.05)

    // Span accross kink.
    // (0.1 * (0.1 + 0.2)) + (0.5 * 0.1 * 0.1) + (0.4 * 0.2) + (0.5 * 0.2 * 0.2 * 0.5))
    assertEq(costModel.areaUnderCurve(0.2e18, 0.5e18), 0.125e54); // Calc above ^^.
    // (0.3 * 0.1) + (0.5 * 0.3 * (0.4 - 0.1)) + (0.7 * 0.4) + (0.5 * 0.7 * (0.75 - 0.4))
    assertEq(costModel.areaUnderCurve(0.0e18, 1.0e18), 0.4775e54); // Calc above ^^.

    // Kink in one or more argument.
    assertEq(costModel.areaUnderCurve(0.0e18, 0.3e18), 0.075e54); // (0.1 * 0.3) + (0.5 * 0.3 * (0.4 - 0.1))
    assertEq(costModel.areaUnderCurve(0.3e18, 1.0e18), 0.4025e54); // (0.7 * 0.4) + (0.5 * 0.7 * (0.75 - 0.4))
    assertEq(costModel.areaUnderCurve(0.2e18, 0.3e18), 0.035e54); // (0.1 * (0.1 + 0.2)) + (0.5 * 0.1 * 0.1)
    assertEq(costModel.areaUnderCurve(0.3e18, 0.8e18), 0.2625e54); // (0.4 * 0.5) + (0.5 * 0.5 * (0.5 * 0.5))

    // All above kink.
    assertEq(costModel.areaUnderCurve(0.9e18, 1.0e18), 0.0725e54); // (0.1 * (0.75 - 0.5*0.1)) + (0.5 * 0.1 * 0.1 * 0.5)
    assertEq(costModel.areaUnderCurve(0.45e18, 0.6e18), 0.076875e54); // (0.15 * (0.4 + 0.15 * 0.5)) + (0.5 * 0.15 * 0.15 * 0.5)
  }
}

contract RoundingTests is CostModelSetup {
  using FixedPointMathLib for uint256;

  function setUp() public virtual override {
    costModel = new MockCostModelJumpRate(
      0.8e18, // kink at 80% utilization
      0.0e18, // 0% fee at no utilization
      0.5e18, // 50% fee at kink utilization
      1.0e18 // 100% fee at full utilization
    );
  }

  function test_CostFactorIsNonZero() public {
    // This is the specific interval over which we noticed the rounding issue.
    testFuzz_CostFactorShouldBeNonZeroOverNonZeroUtilizationRanges(0, 3);
  }

  function testFuzz_CostFactorShouldBeNonZeroOverNonZeroUtilizationRanges(
    uint256 _intervalStart,
    uint256 _intervalEnd
  ) public {
    _intervalStart = bound(_intervalStart, 0, 1e18 - 1);
    _intervalEnd = bound(_intervalEnd, _intervalStart + 1, 1e18);
    uint256 _costFactor = costModel.costFactor(_intervalStart, _intervalEnd);
    assertGt(_costFactor, 0);
  }

  function testFuzz_RefundFactorShouldBeLessThan100PercentOverUtilizationRanges(
    uint256 _intervalStart,
    uint256 _intervalEnd
  ) public {
    _intervalStart = bound(_intervalStart, 1, 3e18 - 1);
    _intervalEnd = bound(_intervalEnd, _intervalStart + 1, 3e18);
    uint256 _refundFactor = costModel.refundFactor(_intervalEnd, _intervalStart);
    assertLt(_refundFactor, 1e18);
  }

  function testFuzz_RefundFactorShouldBe100PercentOverFullUtilizationRanges(
    uint256 _intervalEnd
  ) public {
    uint256 _intervalStart = 0; // Always the full utilization window for this test.
    _intervalEnd = bound(_intervalEnd, 1, 5e18);
    uint256 _refundFactor = costModel.refundFactor(_intervalEnd, _intervalStart);
    assertEq(_refundFactor, 1e18);
  }

  function test_ExtraAreaUnderCurveExamples() public {
    assertEq(costModel.areaUnderCurve(3, 7), 12.5e18);
    assertEq(costModel.areaUnderCurve(0, 7), 15.3125e18);
    assertEq(
      costModel.areaUnderCurve(
        946164736790778453,
        946164736790778457
      ),
    // low  = 946164736790778453
    // high = 946164736790778457
    // slope = rise/run = 0.5/0.2 = 2.5, scaled up by a wad == 2.5e18
    // triangle = 0.5 * 4 * 4 * 2.5e18 = 20e18
    // rectangle = length * height
    //   length = 4
    //   height = kinkRate * wad + (deltaKinkOnX * slope)
    //          = 0.5e18 * 1e18 + (deltaKinkOnX * slope)
    //          = 0.5e36 + (deltaKinkOnX * slope)
    //          = 0.5e36 + (946164736790778453 - kink) * slope
    //          = 0.5e36 + (946164736790778453 - 0.8e18) * 2.5e18
    //    = 4 * (0.5e36 + (946164736790778453 - 0.8e18) * 2.5e18)
    // Adding triangle + rectangle...
    //   3461647367907784530000000000000000000 (rectangle)
    //   +                20000000000000000000 (triangle)
    //   -------------------------------------
    //   3461647367907784550000000000000000000 (total area)
      3461647367907784550000000000000000000
    );
  }

  function testFuzz_RefundFactorOverMultipleRangesShouldDrainFeePool(
    uint256 _intervalLow,
    uint256 _intervalMidLow,
    uint256 _intervalHigh,
    uint256 _feePool
  ) public {
    // The refund factor is meant to be multiplied by the fee pool to determine
    // amounts refunded to customers. So we want to confirm here that you can
    // incrementally apply the refund factors to the fee pool.
    _feePool = bound(_feePool, 1e4, 100e18); // Arbitrary but reasonable bounds.

    uint256 _initFeePool = _feePool;
    _intervalLow = bound(_intervalLow, 0, 5e18 - 3);
    _intervalMidLow = bound(_intervalMidLow, _intervalLow + 1, 5e18 - 2);
    uint256 _intervalMidHigh = _intervalMidLow + 1;
    _intervalHigh = bound(_intervalHigh, _intervalMidHigh + 1, 5e18);
    uint256 _refundFactorA = costModel.refundFactor(_intervalHigh, _intervalMidHigh);
    _feePool -= _feePool.mulWadDown(_refundFactorA);
    uint256 _refundFactorB = costModel.refundFactor(_intervalMidLow, _intervalLow);
    _feePool -= _feePool.mulWadDown(_refundFactorB);
    if (_intervalLow == 0) assertEq(_feePool, 0);
    if (_intervalLow > 0) {
      assertGt(_feePool, 0);
      // In almost all cases _feePool < _initFeePool. But because we round
      // refundFactor down (to favor the protocol) there are very small
      // utilization intervals over which _feePool == _initFeePool even after the
      // refundFactor is applied.
      assertLe(_feePool, _initFeePool);
    }
  }
}
