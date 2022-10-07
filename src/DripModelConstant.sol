// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "cozy-v2-interfaces/interfaces/IDripModel.sol";

/**
 * @notice Constant rate drip model.
 */
contract DripModelConstant is IDripModel {
  uint256 constant internal ONE_YEAR = 365.25 days;

  /// @notice Drip rate per-second.
  uint256 public immutable dripRatePerSecond;

  /// @param _dripRatePerSecond Drip rate per-second.
  constructor(uint256 _dripRatePerSecond) {
    dripRatePerSecond = _dripRatePerSecond;
  }

  /// @notice Returns the current drip rate based on the provided `_utilization`.
  /// @dev For calculating the per-second drip rate, we use the exponential decay formula A = P * (1 - r) ^ t
  /// where A is final amount, P is principal (starting) amount, r is the per-second decay rate, and t is the number of elapsed seconds.
  /// For example, for an annual drip rate of 25%:
  /// A = P * (1 - r) ^ t
  /// 0.75 = 1 * (1 - r) ^ 31557600
  /// -r = 0.75^(1/31557600) - 1
  /// -r = -9.116094732822280932149636651070655494101566187385032e-9
  /// Multiplying r by -1e18 to calculate the scaled up per-second value required by the constructor ~= 9116094774
  function dripRate(uint256 /* _utilization */) external view returns (uint256) {
    return dripRatePerSecond;
  }
}
