// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {CostModelAreaCalculationsLib} from "./lib/CostModelAreaCalculationsLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ICostModel} from "src/interfaces/ICostModel.sol";

/**
 * @notice This instance of CostModel is an extention of the jump rate cost model with a dynamic level.
 *
 * For details, check out the docs:
 * https://github.com/Cozy-Finance/cozy-developer-documentation-v2-refactor/blob/main/src/dynamic-level-model-explainer.md
 */
contract CostModelDynamicLevel is ICostModel {
  using FixedPointMathLib for uint256;

  uint256 internal constant ZERO_UTILIZATION = 0;
  uint256 internal constant FULL_UTILIZATION = FixedPointMathLib.WAD; // 1 wad

  /// @notice Start of optimal utilization zone, as a wad.
  uint256 public immutable uLow;

  /// @notice End of optimal utilization zone, as a wad.
  uint256 public immutable uHigh;

  /// @notice Optimal utilization, as a wad; currently set as 0.5*(uLow + uHigh).
  uint256 public immutable uOpt;

  /// @notice Cost factor to apply at 0% utilization, as a wad.
  uint256 public immutable costFactorAtZeroUtilization;

  /// @notice Cost factor to apply at 100% utilization, as a wad.
  uint256 public immutable costFactorAtFullUtilization;

  /// @notice Rate at which the `costFactorInOptimalZone` changes, as a wad.
  uint256 public immutable optimalZoneRate;

  /// @notice Cost factor to apply in the optimal utilization zone, as a wad.
  uint256 public costFactorInOptimalZone;

  /// @notice The last time the model was updated.
  uint256 public lastUpdateTime;

    /// @notice The set associated with this model.
    address public setAddress;

  /// @dev Thrown when the current time is not after `lastUpdateTime`.
  error InvalidTime();

  /// @dev Thrown when the utilization inputs passed to a method are out of bounds.
  error InvalidUtilization();

  /// @dev Thrown when a set of cost model parameters are not within valid bounds.
  error InvalidConfiguration();

    /// @dev Thrown when the cost model's set address has already been registered.
    error SetAlreadyRegistered();

    /// @dev Thrown when the caller is not authorized to perform the action.
    error Unauthorized();

  /// @dev Emitted whenever model state variables are updated.
  event UpdatedDynamicLevelModelParameters(uint256 costFactorInOptimalZone, uint256 lastUpdateTime);

  /// @param uLow_ Start of optimal utilization zone, as a wad.
  /// @param uHigh_ End of optimal utilization zone, as a wad.
  /// @param costFactorAtZeroUtilization_ Cost factor to apply at 0% utilization, as a wad.
  /// @param costFactorAtFullUtilization_ Cost factor to apply at 100% utilization, as a wad.
  /// @param costFactorInOptimalZone_ Cost factor to apply in the optimal utilization zone, as a wad.
  /// @param optimalZoneRate_ Rate at which the `costFactorInOptimalZone` changes, as a wad.
  constructor(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 optimalZoneRate_
  ) {
    if (uHigh_ > FixedPointMathLib.WAD) revert InvalidConfiguration();
    if (uLow_ > uHigh_) revert InvalidConfiguration();
    if (costFactorAtFullUtilization_ > FixedPointMathLib.WAD) revert InvalidConfiguration();
    if (costFactorAtFullUtilization_ < costFactorAtZeroUtilization_) revert InvalidConfiguration();

    uLow = uLow_;
    uHigh = uHigh_;
    uOpt = (uLow_ + uHigh_).mulDivUp(1, 2);
    costFactorAtZeroUtilization = costFactorAtZeroUtilization_;
    costFactorAtFullUtilization = costFactorAtFullUtilization_;
    optimalZoneRate = optimalZoneRate_;
    costFactorInOptimalZone = costFactorInOptimalZone_;
    lastUpdateTime = block.timestamp;
  }

  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param fromUtilization_ Initial utilization of the market.
  /// @param toUtilization_ Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 fromUtilization_, uint256 toUtilization_) external view returns (uint256) {
    if (toUtilization_ < fromUtilization_) revert InvalidUtilization();
    if (toUtilization_ > FULL_UTILIZATION) revert InvalidUtilization();

    (uint256 costFactorInOptimalZone_,) = _getUpdatedStorageParams(block.timestamp, fromUtilization_);

    if (fromUtilization_ == toUtilization_) {
      return _pointOnCurve(costFactorInOptimalZone_, toUtilization_);
    } else {
      // Otherwise: divide the area under the curve by the interval of utilization
      // to get the average cost factor over that interval. We scale the
      // denominator up by another wad (which makes it wad^2 based) because the
      // numerator is going to be scaled up by wad^3 and we want the final value
      // to just be scaled up by wad^1.
      uint256 denominator_ = (toUtilization_ - fromUtilization_) * FixedPointMathLib.WAD;

      // We want to round up to favor the protocol here, since this determines the cost of protection.
      return _areaUnderCurve(fromUtilization_, toUtilization_, costFactorInOptimalZone_).mulDivUp(1, denominator_);
    }
  }

  /// @notice Gives the refund value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @dev Refund factors, unlike cost factors, are defined for utilization above 100%, since markets
  /// can become over-utilized and protection can be sold in those cases.
  /// @param fromUtilization_ Initial utilization of the market.
  /// @param toUtilization_ Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 fromUtilization_, uint256 toUtilization_) external view returns (uint256) {
    if (fromUtilization_ < toUtilization_) revert InvalidUtilization();
    if (fromUtilization_ == toUtilization_) return 0;

    (uint256 costFactorInOptimalZone_,) = _getUpdatedStorageParams(block.timestamp, fromUtilization_);

    // Formula is: (area-under-return-interval / total-area-under-utilization-to-zero).
    // But we do all multiplication first so that we avoid precision loss.
    uint256 areaWithinRefundInterval_ = _areaUnderCurve(toUtilization_, fromUtilization_, costFactorInOptimalZone_);
    uint256 areaUnderFullUtilizationWindow_ =
      _areaUnderCurve(ZERO_UTILIZATION, fromUtilization_, costFactorInOptimalZone_);

    // Both areas are scaled up by wad^3, which cancels out during division. We
    // scale up by an additional wad so that the percentage resulting from their
    // division will be wad-based.
    uint256 numerator_ = areaWithinRefundInterval_ * FixedPointMathLib.WAD;
    uint256 denominator_ = areaUnderFullUtilizationWindow_;
    // We round down to favor the protocol.
    return numerator_ / denominator_;
  }

  /// @dev Returns the area under the curve between the `intervalLowPoint_` and `intervalHighPoint_`, scaled up by
  /// wad^3.
  function _areaUnderCurve(uint256 intervalLowPoint_, uint256 intervalHighPoint_, uint256 costFactorInOptimalZone_)
    internal
    view
    returns (uint256)
  {
    if (intervalHighPoint_ < intervalLowPoint_) revert InvalidUtilization();

    // Area over the x-axis range [ZERO_UTILIZATION, uLow).
    uint256 firstArea_ = intervalLowPoint_ > uLow
      ? 0
      : CostModelAreaCalculationsLib.areaUnderCurve(
        _slopeAtUtilizationPoint(costFactorInOptimalZone_, intervalLowPoint_),
        intervalLowPoint_,
        (intervalHighPoint_ > uLow ? uLow : intervalHighPoint_),
        ZERO_UTILIZATION,
        costFactorAtZeroUtilization
      );

    // Area over the x-axis range [uLow, uHigh].
    uint256 secondArea_ = ((intervalHighPoint_ < uLow) || (intervalLowPoint_ > uHigh))
      ? 0
      : CostModelAreaCalculationsLib.areaUnderCurve(
        0,
        (intervalLowPoint_ > uLow ? intervalLowPoint_ : uLow),
        (intervalHighPoint_ < uHigh ? intervalHighPoint_ : uHigh),
        uLow,
        costFactorInOptimalZone_
      );

    // Area over the x-axis range (uHigh, FULL_UTILIZATION].
    uint256 thirdArea_ = intervalHighPoint_ < uHigh
      ? 0
      : CostModelAreaCalculationsLib.areaUnderCurve(
        _slopeAtUtilizationPoint(costFactorInOptimalZone_, intervalHighPoint_),
        (intervalLowPoint_ > uHigh ? intervalLowPoint_ : uHigh),
        intervalHighPoint_,
        uHigh,
        costFactorInOptimalZone_
      );

    return firstArea_ + secondArea_ + thirdArea_;
  }

  /// @dev Returns slope at the specified `_utilization` as a wad.
  function _slopeAtUtilizationPoint(uint256 costFactorInOptimalZone_, uint256 utilization_)
    internal
    view
    returns (uint256)
  {
    // The cost factor is just the slope of the curve where x-axis=utilization and y-axis=cost.
    // slope = delta y / delta x = change in cost factor / change in utilization.
    if (utilization_ < uLow) {
      return uLow == ZERO_UTILIZATION
        ? 0
        : (costFactorInOptimalZone_ - costFactorAtZeroUtilization).divWadUp(uLow - ZERO_UTILIZATION);
    } else if (utilization_ <= uHigh) {
      return 0;
    } else {
      return uHigh == FULL_UTILIZATION
        ? 0
        : (costFactorAtFullUtilization - costFactorInOptimalZone_).divWadUp(FULL_UTILIZATION - uHigh);
    }
  }

  /// @dev Returns the cost factor (y-coordinate) of the point where the utilization equals the given `utilization_`
  /// (x-coordinate).
  function _pointOnCurve(uint256 costFactorInOptimalZone_, uint256 utilization_) internal view returns (uint256) {
    if (utilization_ > uHigh) {
      return (utilization_ - uHigh).mulWadUp(_slopeAtUtilizationPoint(costFactorInOptimalZone_, utilization_))
        + costFactorInOptimalZone_;
    } else if (utilization_ >= uLow) {
      return costFactorInOptimalZone_;
    } else {
      return utilization_.mulWadUp(_slopeAtUtilizationPoint(costFactorInOptimalZone_, utilization_))
        + costFactorAtZeroUtilization;
    }
  }

  /// @dev Returns the value of the dynamically updated `costFactorInOptimalZone`.
  /// @param utilization_ Current utilization.
  /// @param timeDelta_ Time since last update.
  function _computeNewCostFactorInOptimalZone(uint256 utilization_, uint256 timeDelta_) internal view returns (uint256) {
    uint256 currentCostFactorInOptimalZone_ = costFactorInOptimalZone;
    if (utilization_ >= uOpt) {
      // Cost factor increases with `timeDelta` and `utilization - uOpt`, but with a ceiling set at
      // `costFactorAtFullUtilization`.
      return _min(
        currentCostFactorInOptimalZone_ + optimalZoneRate.mulWadUp((utilization_ - uOpt) * timeDelta_),
        costFactorAtFullUtilization
      );
    } else {
      // Cost factor decreases with `timeDelta` and `utilization - uOpt`, but with a floor set at
      // `costFactorAtZeroUtilization`.
      uint256 delta_ = optimalZoneRate.mulWadUp((uOpt - utilization_) * timeDelta_);
      if (delta_ > currentCostFactorInOptimalZone_ - costFactorAtZeroUtilization) return costFactorAtZeroUtilization;
      else return currentCostFactorInOptimalZone_ - delta_;
    }
  }

  /// @dev Returns the  values of the dynamically updated storage variables, `costFactorInOptimalZone` and
  /// `lastUpdateTime`.
  /// @param currentTime_ Current timestamp.
  /// @param utilization_ Current utilization.
  function _getUpdatedStorageParams(uint256 currentTime_, uint256 utilization_)
    internal
    view
    returns (uint256 newCostFactorInOptimalZone_, uint256 newLastUpdateTime_)
  {
    uint256 lastUpdateTime_ = lastUpdateTime;
    if (currentTime_ < lastUpdateTime_) revert InvalidTime();
    newCostFactorInOptimalZone_ = _computeNewCostFactorInOptimalZone(utilization_, currentTime_ - lastUpdateTime_);
    newLastUpdateTime_ = currentTime_;
  }

  /// @dev Called by the Cozy protocol to update the model's storage variables.
  function update(uint256 utilization_, uint256 newUtilization_) external onlySet {
    (costFactorInOptimalZone, lastUpdateTime) = _getUpdatedStorageParams(block.timestamp, newUtilization_);
    emit UpdatedDynamicLevelModelParameters(costFactorInOptimalZone, lastUpdateTime);
  }

    /// @dev Called in the protocol by the Set contract to register the Set associated with this cost model.
    function registerSet() external {
        address setAddress_ = setAddress;
        if (setAddress_ != address(0) && setAddress_ != msg.sender) revert SetAlreadyRegistered();
        setAddress = msg.sender;
    }

    /// @dev Checks that msg.sender is the set address.
    modifier onlySet() {
        if (msg.sender != setAddress) revert Unauthorized();
        _;
    }

  function _min(uint256 a, uint256 b) public pure returns (uint256) {
    return a >= b ? b : a;
  }
}
