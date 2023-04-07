// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "solmate/utils/FixedPointMathLib.sol";

library CostModelAreaCalculationsLib {
  using FixedPointMathLib for uint256;

  /// @dev Thrown when the parameters to `areaUnderCurve` are invalid. See that method for more information.
  error InvalidReferencePoint();

  /// @dev Compute the area under the cost factor curve within an interval of utilization, scaled up by wad^3.
  ///
  /// For any interval, the shape of the area under the curve is:
  ///
  /// ```
  ///     ^
  ///     |
  ///  F  |           ^
  ///  a  |         / |
  ///  c  |       /   |
  ///  t  |     /     |
  ///  o  |     |     |
  ///  r  |     |     |
  ///     `-----|-----|------------>
  ///         Utilization %
  /// ```
  ///
  /// i.e. a triangle on top of a rectangle:
  ///
  /// ```
  ///                 ^
  ///               / |
  ///             /   | <-- triangle
  ///           /_____|
  ///           |     |
  ///           |     | <-- rectangle
  ///           `-----'
  /// ```
  ///
  /// @param slope_ Slope of the curve within the interval, expressed as a wad, i.e. 0.25e18 is a slope of 0.25.
  /// @param intervalLowPoint_ An X-coordinate on our cost factor curve; it is a wad percentage, i.e. 0.8e18 is 80%
  /// @param intervalHighPoint_ An X-coordinate on our cost factor curve; it is a wad percentage, i.e. 0.8e18 is 80%
  /// @param referencePointX_ The X-coordinate of a point through which the curve passes when it has `slope` slope and
  /// an x-value <= intervalLowPoint.
  /// @param referencePointY_ The Y-coordinate of the same point.
  function areaUnderCurve(
    uint256 slope_,
    uint256 intervalLowPoint_,
    uint256 intervalHighPoint_,
    uint256 referencePointX_,
    uint256 referencePointY_
  ) internal pure returns (uint256) {
    if (intervalLowPoint_ < referencePointX_) revert InvalidReferencePoint();

    uint256 length_ = intervalHighPoint_ - intervalLowPoint_;

    // The top is a triangle, so this is just == 0.5 * length * base.
    // Length and slope have both been scaled up by a wad, so areaOfTop has been
    // scaled up by wad^3 overall.
    uint256 areaOfTop_ = (length_ * (slope_ * length_)) / 2;

    // All of the variables in the line below have been scaled up by a wad. For
    // this reason, multiplying `(_intervalLowPoint - _referencePointX) * _slope`
    // produces a value that has been scaled up by wad^2, and thus can't be
    // meaningfully be added to `_referencePointY`, which has only been scaled
    // up by wad^1. Hence, we multiply the latter by another wad. This results
    // in a final areaOfBottom which has been scaled up by wad^3.
    uint256 heightOfBottom_ =
      (FixedPointMathLib.WAD * referencePointY_) + (intervalLowPoint_ - referencePointX_) * slope_;
    uint256 areaOfBottom_ = heightOfBottom_ * length_; // The bottom is a rectangle.

    return areaOfTop_ + areaOfBottom_;
  }
}
