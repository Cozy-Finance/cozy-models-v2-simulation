// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "solmate/utils/FixedPointMathLib.sol";
import "src/interfaces/ICostModel.sol";
import "test/utils/MockCostModelDynamicLevel.sol";

contract CostModelSetup is Test {
    using FixedPointMathLib for uint256;

    MockCostModelDynamicLevel costModel;

    function setUp() public virtual {
        costModel = new MockCostModelDynamicLevel({
          uLow_: 0.25e18,
          uHigh_: 0.75e18,
          costFactorAtZeroUtilization_: 0.005e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.1e18,
          optimalZoneRate_: 5e11
        }
    );
    }
}

contract CostFactorRevertTest is CostModelSetup {
    function testFuzz_CostFactorRevertsIfNewUtilizationIsLowerThanOld(uint256 oldUtilization, uint256 newUtilization)
        public
    {
        vm.assume(newUtilization != oldUtilization);
        if (newUtilization > oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
        vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
        costModel.costFactor(oldUtilization, newUtilization);
    }

    function testFuzz_CostFactorRevertsIfNewUtilizationIsGreaterThan100(uint256 oldUtilization, uint256 newUtilization)
        public
    {
        vm.assume(newUtilization > 1e18);
        vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
        costModel.costFactor(oldUtilization, newUtilization);
    }
}

contract CostFactorPointInTimeTest is CostModelSetup {
    function test_CostFactorOverSpecificUtilizationIntervals() public {
        assertEq(costModel.costFactor(0.0e18, 0.25e18), 0.525e17);
        assertEq(costModel.costFactor(0.0e18, 0.3e18), 0.60416666666666667e17);
        assertEq(costModel.costFactor(0.1e18, 0.2e18), 0.62e17);
        assertEq(costModel.costFactor(0.1e18, 0.6e18), 0.9145e17);
        assertEq(costModel.costFactor(0.0e18, 1.0e18), 0.200625e18);
        assertEq(costModel.costFactor(0.4e18, 0.8e18), 0.11125e18);
        assertEq(costModel.costFactor(0.75e18, 1.0e18), 0.55e18);
        assertEq(costModel.costFactor(0.0e18, 0.8e18), 0.9078125e17);
        assertEq(costModel.costFactor(0.2e18, 0.8e18), 0.106708333333333334e18);
        assertEq(costModel.costFactor(0.9e18, 1.0e18), 0.82e18);
        assertEq(costModel.costFactor(0.9e18, 0.999e18), 0.8182e18);
    }

    function test_CostFactorWhenIntervalIsZero() public {
        assertEq(costModel.costFactor(0.0e18, 0.0e18), 0.5e16);
        assertEq(costModel.costFactor(0.8e18, 0.8e18), 0.28e18);
        assertEq(costModel.costFactor(1.0e18, 1.0e18), 1e18);
        assertEq(costModel.costFactor(0.05e18, 0.05e18), 0.24e17);
        assertEq(costModel.costFactor(0.1e18, 0.1e18), 0.43e17);
        assertEq(costModel.costFactor(0.2e18, 0.2e18), 0.81e17);
        assertEq(costModel.costFactor(0.4e18, 0.4e18), 0.1e18);
        assertEq(costModel.costFactor(0.9e18, 0.9e18), 0.64e18);
        assertEq(costModel.costFactor(0.95e18, 0.95e18), 0.82e18);
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

        uint256 feeAmountTwoIntervals =
        //  |<----------------------- feeAmountA * 1e36 ----------------------->|
        //  |<------------ protectionAmountA * 1e18 ------------->|
        (
            (intervalMidPoint - intervalLowPoint) * totalProtection * costFactorA
            //  |<----------------------- feeAmountN * 1e36 ----------------------->|
            //  |<------------ protectionAmountB * 1e18 ------------->|
            + (intervalHighPoint - intervalMidPoint) * totalProtection * costFactorB
        ) / 1e36;

        // Now do the same thing but over a single interval.
        uint256 protectionAmountOneInterval = (intervalHighPoint - intervalLowPoint) * totalProtection / 1e18;
        uint256 costFactorOneInterval = costModel.costFactor(intervalLowPoint, intervalHighPoint);
        uint256 feeAmountOneInterval = protectionAmountOneInterval * costFactorOneInterval / 1e18;

        if (feeAmountOneInterval > 100) {
            // The fees will differ slightly because of integer division rounding.
            assertApproxEqRel(feeAmountOneInterval, feeAmountTwoIntervals, 0.01e18);
        } else {
            assertApproxEqAbs(feeAmountOneInterval, feeAmountTwoIntervals, 1);
        }
    }

    function testFuzz_CostFactorAlwaysBelowCostFactorAtFullUtilization(uint256 fromUtilization_, uint256 toUtilization_)
        public
    {
        fromUtilization_ = bound(fromUtilization_, 0, 1e18);
        toUtilization_ = bound(toUtilization_, fromUtilization_, 1e18);
        assertLe(costModel.costFactor(fromUtilization_, toUtilization_), costModel.costFactorAtFullUtilization() + 1);
    }

    function testFuzz_CostFactorAlwaysAboveCostFactorAtZeroUtilization(uint256 fromUtilization_, uint256 toUtilization_)
        public
    {
        fromUtilization_ = bound(fromUtilization_, 0, 1e18);
        toUtilization_ = bound(toUtilization_, fromUtilization_, 1e18);
        assertGe(costModel.costFactor(fromUtilization_, toUtilization_), costModel.costFactorAtZeroUtilization());
    }
}

contract CostFactorOverTimeTest is CostModelSetup {
    function test_CostFactorOverSpecificUtilizationIntervalDynamic() public {
        // Cost comes down over time as no one purchases.
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.9078125e17);
        skip(1);
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.90781040625e17);
        skip(1_000);
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.90571665625e17);
        skip(1_000_000_000);
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.1121875e17);
        // Cost goes up once utilization goes up.
        costModel.update(0e18, 0.8e18);
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.84453125e18);
        // Cost goes down.
        skip(1_000);
        assertEq(costModel.costFactor(0e18, 0.8e18), 0.844321875e18);
    }

    function test_CostFactorInOptimalZoneConvergesToLowerBound() public {
        skip(1_000_000_000_000_000_000);
        costModel.update(0e18, 0e18);
        assertEq(costModel.costFactorAtZeroUtilization(), costModel.costFactorInOptimalZone());
        assertEq(costModel.lastUpdateTime(), block.timestamp);
    }
}

contract CostFactorStraightLineTest is Test {
    using FixedPointMathLib for uint256;

    MockCostModelDynamicLevel costModel;

    function setUp() public virtual {
        costModel = new MockCostModelDynamicLevel({
          uLow_: 0,
          uHigh_: 1e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.25e18,
          optimalZoneRate_: 5e11
        }
    );
    }

    function test_CostFactorIsConstant() public {
        assertEq(costModel.costFactor(0, 0), 0.25e18);
        assertEq(costModel.costFactor(0.25e18, 0.25e18), 0.25e18);
        assertEq(costModel.costFactor(0.7e18, 0.7e18), 0.25e18);
        assertEq(costModel.costFactor(1e18, 1e18), 0.25e18);
        assertEq(costModel.costFactor(0.3e18, 0.4e18), 0.25e18);
        assertEq(costModel.costFactor(0.3e18, 0.9e18), 0.25e18);
        assertEq(costModel.costFactor(0e18, 1e18), 0.25e18);
    }

    function test_CostFactorIsConstantOverTime() public {
        skip(1);
        (uint256 costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0);
        assertEq(costModel.costFactor(0, 0), costFactorInOptimalZone_);
        assertEq(costModel.costFactor(0, 0.2e18), costFactorInOptimalZone_);
        (costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0.5e18);
        assertEq(costModel.costFactor(0.5e18, 0.75e18), costFactorInOptimalZone_);
        assertEq(costModel.costFactor(0.5e18, 1e18), costFactorInOptimalZone_);

        skip(1_000_000);
        (costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0.1e18);
        assertEq(costModel.costFactor(0.1e18, 0.1e18), costFactorInOptimalZone_);
        assertEq(costModel.costFactor(0.1e18, 0.9e18), costFactorInOptimalZone_);
        assertEq(costModel.costFactor(0.1e18, 1e18), costFactorInOptimalZone_);

        skip(1_000_000_00);
        assertEq(costModel.costFactor(0.04e18, 0.1e18), 0.1e18);
        assertEq(costModel.costFactor(0.1e18, 0.9e18), 0.1e18);
        assertEq(costModel.costFactor(0.1e18, 1e18), 0.1e18);
    }
}

contract CostModelDeploy is CostModelSetup {
    function testFuzz_ConstructorRevertsWhenUtilizationArgumentsAreMisspecified(uint256 uLow_, uint256 uHigh_) public {
        vm.assume(uHigh_ > FixedPointMathLib.WAD || uLow_ > uHigh_);
        vm.expectRevert(CostModelDynamicLevel.InvalidConfiguration.selector);
        new CostModelDynamicLevel({
          uLow_: uLow_,
          uHigh_: uHigh_,
          costFactorAtZeroUtilization_: 0.005e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.1e18,
          optimalZoneRate_: 5e11
        });
    }

    function testFuzz_ConstructorRevertsWhenBoundsAreMisspecified(
        uint256 costFactorAtZeroUtilization_,
        uint256 costFactorAtFullUtilization_
    ) public {
        vm.assume(
            costFactorAtFullUtilization_ > FixedPointMathLib.WAD
                || costFactorAtZeroUtilization_ > costFactorAtFullUtilization_
        );
        vm.expectRevert(CostModelDynamicLevel.InvalidConfiguration.selector);
        new CostModelDynamicLevel({
          uLow_: 0.25e18,
          uHigh_: 0.75e18,
          costFactorAtZeroUtilization_: costFactorAtZeroUtilization_,
          costFactorAtFullUtilization_: costFactorAtFullUtilization_,
          costFactorInOptimalZone_: 0.1e18,
          optimalZoneRate_: 5e11
        });
    }
}

contract RefundFactorRevertTest is CostModelSetup {
    function testFuzz_RefundFactorRevertsIfOldUtilizationIsLowerThanNew(uint256 oldUtilization, uint256 newUtilization)
        public
    {
        vm.assume(newUtilization != oldUtilization);
        if (newUtilization < oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
        vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
        costModel.refundFactor(oldUtilization, newUtilization);
    }
}

contract RefundFactorPointInTimeTest is CostModelSetup {
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
        assertEq(costModel.refundFactor(0.2e18, 0.0e18), 1e18); // all of the fees
        assertEq(costModel.refundFactor(0.5e18, 0.0e18), 1e18); // all of the fees
        assertEq(costModel.refundFactor(0.2e18, 0.1e18), 0.720930232558139534e18);
        assertApproxEqRel(costModel.refundFactor(0.9e18, 0.5e18), 0.678609062170706006e18, 1e10);
        assertEq(costModel.refundFactor(1.0e18, 0.0e18), 1e18); // all of the fees
        assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.8e18), 0.638006230529595015e18, 1);
        assertApproxEqRel(costModel.refundFactor(0.9e18, 0.8e18), 0.387776606954689146e18, 1e10);
        assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.4e18), 0.612736660929432013e18, 1);
        assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.2e18), 0.881583476764199655e18, 1);
        assertEq(costModel.refundFactor(0.8e18, 0.0e18), 1e18);
        assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.9e18), 0.408722741433021806e18, 1);

        // Above 100% utilization.
        assertEq(costModel.refundFactor(1.6e18, 1.5e18), 0.205712313400638536e18);
        assertEq(costModel.refundFactor(1.6e18, 1.2e18), 0.673742341875916817e18);
        assertEq(costModel.refundFactor(1.6e18, 1e18), 0.861506601087237898e18);
        assertEq(costModel.refundFactor(1.6e18, 0.8e18), 0.949866252480800759e18);
        assertEq(costModel.refundFactor(1.6e18, 0.0e18), 1e18); // all of the fees
    }

    function test_RefundFactorWhenIntervalIsZero(uint256 _utilization) public {
        _utilization = bound(_utilization, 0, 1.0e18);
        assertEq(costModel.refundFactor(_utilization, _utilization), 0);
    }
}

contract CostModelCompareParametersTest is Test {
    using FixedPointMathLib for uint256;

    function testFuzz_CheaperCostModelHasLowerCosts(
        uint256 costFactorInOptimalZoneCheap_,
        uint256 costFactorInOptimalZoneExpensive_
    ) public {
        costFactorInOptimalZoneCheap_ = bound(costFactorInOptimalZoneCheap_, 0e18, 1e18);
        costFactorInOptimalZoneExpensive_ =
            bound(costFactorInOptimalZoneExpensive_, costFactorInOptimalZoneCheap_, 1e18);
        MockCostModelDynamicLevel costModelCheap = new MockCostModelDynamicLevel({
            uLow_: 0.25e18,
            uHigh_: 0.75e18,
            costFactorAtZeroUtilization_: 0e18,
            costFactorAtFullUtilization_: 1e18,
            costFactorInOptimalZone_: costFactorInOptimalZoneCheap_,
            optimalZoneRate_: 5e11
        });
        MockCostModelDynamicLevel costModelExpensive = new MockCostModelDynamicLevel({
            uLow_: 0.25e18,
            uHigh_: 0.75e18,
            costFactorAtZeroUtilization_: 0e18,
            costFactorAtFullUtilization_: 1e18,
            costFactorInOptimalZone_: costFactorInOptimalZoneExpensive_,
            optimalZoneRate_: 5e11
        });
        assertGe(costModelExpensive.costFactor(0.5e18, 0.5e18), costModelCheap.costFactor(0.5e18, 0.5e18));
        assertGe(costModelExpensive.costFactor(0e18, 0.5e18), costModelCheap.costFactor(0e18, 0.5e18));
        assertGe(costModelExpensive.costFactor(0.5e18, 1e18), costModelCheap.costFactor(0.5e18, 1e18));
        assertGe(costModelExpensive.costFactor(0.2e18, 0.8e18), costModelCheap.costFactor(0.2e18, 0.8e18));
    }
}
