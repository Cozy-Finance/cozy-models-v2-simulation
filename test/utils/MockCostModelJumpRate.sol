// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/CostModelJumpRate.sol";

contract MockCostModelJumpRate is CostModelJumpRate {

  constructor(
    uint256 _kink,
    uint256 _rateAtZeroUtilization,
    uint256 _rateAtKinkUtilization,
    uint256 _rateAtFullUtilization,
    uint256 _cancellationPenalty
  ) CostModelJumpRate(
    _kink,
    _rateAtZeroUtilization,
    _rateAtKinkUtilization,
    _rateAtFullUtilization,
    _cancellationPenalty
  ) {}

  function areaUnderCurve(
    uint256 _intervalLowPoint,
    uint256 _intervalHighPoint
  ) public view returns(uint256) {
    return _areaUnderCurve(_intervalLowPoint, _intervalHighPoint);
  }
}
