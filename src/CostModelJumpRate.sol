// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {CostModelAreaCalculationsLib} from "src/lib/CostModelAreaCalculationsLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "src/interfaces/ICostModel.sol";

/**
 * @notice This instance of CostModel is meant to cover cost factor curves with the following general shape:
 *
 * ```
 *     ^
 *     |                   /
 *     |                  /
 *  F  |                 /
 *  a  |                /
 *  c  |             _-` (kink)
 *  t  |          _-`
 *  o  |       _-`
 *  r  |    _-`
 *     | _-`
 *     `--------------------->
 *           Utilization %
 * ```
 *
 * Where:
 *   - cost = amount * costFactor
 *
 * Definitions:
 *   - cost = the fee charged for the amount of protection
 *   - amount = the amount of protection
 *   - costFactor = a scale factor applied to the protection amount
 *   - kink = the inflection point at which the rate changes
 *
 * For such curves, cost factor increases linearly to a point (the "kink") after which its rate of
 * change is different.
 */
contract CostModelJumpRate is ICostModel {
  using FixedPointMathLib for uint256;

  uint256 constant internal ZERO_UTILIZATION = 0;
  uint256 constant internal FULL_UTILIZATION = FixedPointMathLib.WAD; // 1 wad

  /// @notice Cost factor to apply at 0% utilization, as a wad.
  uint256 public immutable costFactorAtZeroUtilization;

  /// @notice Cost factor to apply at `kink`% utilization, as a wad.
  uint256 public immutable costFactorAtKinkUtilization;

  /// @notice Cost factor to apply at 100% utilization, as a wad.
  uint256 public immutable costFactorAtFullUtilization;

  /// @notice Utilization percentage at which the rate of cost factor change increases, as a wad.
  uint256 public immutable kink;

  /// @dev Thrown when the utilization inputs passed to a method are out of bounds.
  error InvalidUtilization();

  /// @dev Thrown when a set of cost model parameters are not within valid bounds.
  error InvalidConfiguration();

  /// @param _kink The utilization percentage at which the rate of cost factor change increases, as a wad.
  /// @param _costFactorAtZeroUtilization The cost factor to apply at 0% utilization, as a wad.
  /// @param _costFactorAtKinkUtilization The cost factor to apply at `kink`% utilization, as a wad.
  /// @param _costFactorAtFullUtilization The cost factor to apply at 100% utilization, as a wad.
  constructor(
    uint256 _kink,
    uint256 _costFactorAtZeroUtilization,
    uint256 _costFactorAtKinkUtilization,
    uint256 _costFactorAtFullUtilization
  ) {
    if (_kink > FULL_UTILIZATION) revert InvalidConfiguration();
    if (_costFactorAtZeroUtilization > FixedPointMathLib.WAD) revert InvalidConfiguration();
    if (_costFactorAtKinkUtilization > FixedPointMathLib.WAD) revert InvalidConfiguration();
    if (_costFactorAtFullUtilization > FixedPointMathLib.WAD) revert InvalidConfiguration();

    kink = _kink;
    costFactorAtZeroUtilization = _costFactorAtZeroUtilization;
    costFactorAtKinkUtilization = _costFactorAtKinkUtilization;
    costFactorAtFullUtilization = _costFactorAtFullUtilization;
  }

  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param _fromUtilization Initial utilization of the market.
  /// @param _toUtilization Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 _fromUtilization, uint256 _toUtilization) external view returns (uint256) {
    if (_toUtilization < _fromUtilization) revert InvalidUtilization();
    if (_toUtilization > FULL_UTILIZATION) revert InvalidUtilization();

    // When the utilization interval is zero, we return the instantaneous cost factor.
    // In _pointOnCurve, we round up to favor the protocol.
    if (_fromUtilization == _toUtilization) return _pointOnCurve(_toUtilization);

    // Otherwise: divide the area under the curve by the interval of utilization
    // to get the average cost factor over that interval. We scale the
    // denominator up by another wad (which makes it wad^2 based) because the
    // numerator is going to be scaled up by wad^3 and we want the final value
    // to just be scaled up by wad^1.
    uint256 _denominator = (_toUtilization - _fromUtilization) * FixedPointMathLib.WAD;
    // We want to round up to favor the protocol here, since this determines the cost of protection.
    return _areaUnderCurve(_fromUtilization, _toUtilization).mulDivUp(1, _denominator);
  }

  /// @notice Gives the refund value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @param _fromUtilization Initial utilization of the market.
  /// @param _toUtilization Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 _fromUtilization, uint256 _toUtilization) external view returns (uint256) {
    if (_fromUtilization < _toUtilization) revert InvalidUtilization();
    if (_fromUtilization > FULL_UTILIZATION) revert InvalidUtilization();
    if (_fromUtilization == _toUtilization) return 0;

    // Formula is: (area-under-return-interval / total-area-under-utilization-to-zero).
    // But we do all multiplication first so that we avoid precision loss.
    uint256 _areaWithinRefundInterval = _areaUnderCurve(_toUtilization, _fromUtilization);
    uint256 _areaUnderFullUtilizationWindow = _areaUnderCurve(ZERO_UTILIZATION, _fromUtilization);
    // Both areas are scaled up by wad^3, which cancels out during division. We
    // scale up by an additional wad so that the percentage resulting from their
    // division will be wad-based.
    uint256 _numerator = _areaWithinRefundInterval * FixedPointMathLib.WAD;
    uint256 _denominator = _areaUnderFullUtilizationWindow;
    // We round down to favor the protocol.
    return _numerator / _denominator;
  }

  /// @dev Returns the area under the curve between the `_intervalLowPoint` and `_intervalHighPoint`, scaled up by wad^3.
  function _areaUnderCurve(uint256 _intervalLowPoint, uint256 _intervalHighPoint) internal view returns(uint256) {
    if (_intervalHighPoint < _intervalLowPoint) revert InvalidUtilization();

    uint256 _areaBeforeKink = CostModelAreaCalculationsLib.areaUnderCurve(
      _slopeAtUtilizationPoint(ZERO_UTILIZATION),
      (_intervalLowPoint < kink ? _intervalLowPoint : kink),
      (_intervalHighPoint < kink ? _intervalHighPoint : kink),
      ZERO_UTILIZATION,
      costFactorAtZeroUtilization
    );
    uint256 _areaAfterKink = CostModelAreaCalculationsLib.areaUnderCurve(
      _slopeAtUtilizationPoint(FULL_UTILIZATION),
      (_intervalLowPoint > kink ? _intervalLowPoint : kink),
      (_intervalHighPoint > kink ? _intervalHighPoint : kink),
      kink,
      costFactorAtKinkUtilization
    );

    return _areaBeforeKink + _areaAfterKink;
  }

  /// @dev Returns slope at the specified `_utilization` as a wad.
  function _slopeAtUtilizationPoint(uint256 _utilization) internal view returns (uint256) {
    // The cost factor is just the slope of the curve where x-axis=utilization and y-axis=cost.
    // slope = delta y / delta x = change in cost factor / change in utilization.
    if (_utilization <= kink) return (costFactorAtKinkUtilization - costFactorAtZeroUtilization).divWadDown((kink - ZERO_UTILIZATION));
    return (costFactorAtFullUtilization - costFactorAtKinkUtilization).divWadDown(FULL_UTILIZATION - kink);
  }

  /// @dev Returns the cost factor (y-coordinate) of the point where the utilization equals the given `_utilization` (x-coordinate).
  function _pointOnCurve(uint256 _utilization) internal view returns (uint256) {
    if (_utilization == ZERO_UTILIZATION) return costFactorAtZeroUtilization;
    if (_utilization == FULL_UTILIZATION) return costFactorAtFullUtilization;
    if (_utilization == kink)             return costFactorAtKinkUtilization;

    uint256 _deltaX = _utilization < kink ? _utilization : (_utilization - kink);
    uint256 _offsetY = _utilization < kink ? costFactorAtZeroUtilization : costFactorAtKinkUtilization;
    uint256 _slope = _slopeAtUtilizationPoint(_utilization);

    return _deltaX.mulWadUp(_slope) + _offsetY;
  }

  /// @dev The jump rate model is static, so it has no need to update storage variables.
  function update(uint256 _fromUtilization, uint256 _toUtilization) external {}
}
