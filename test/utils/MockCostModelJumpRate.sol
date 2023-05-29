// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {CostModelJumpRate} from "contracts/CostModelJumpRate.sol";

contract MockCostModelJumpRate is CostModelJumpRate {
  constructor(
    uint256 _kink,
    uint256 _rateAtZeroUtilization,
    uint256 _rateAtKinkUtilization,
    uint256 _rateAtFullUtilization
  ) CostModelJumpRate(_kink, _rateAtZeroUtilization, _rateAtKinkUtilization, _rateAtFullUtilization) {}

  function areaUnderCurve(uint256 _intervalLowPoint, uint256 _intervalHighPoint) public view returns (uint256) {
    return _areaUnderCurve(_intervalLowPoint, _intervalHighPoint);
  }
}
