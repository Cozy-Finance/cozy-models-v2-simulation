// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "solmate/utils/FixedPointMathLib.sol";

uint256 constant MAX_INT256 = uint256(type(int256).max);
  
/// @dev Calculate the exponential drip/decay rate, according to   
///   A = P * (1 - r) ^ t
/// where:
///   A is final amount.
///   P is principal (starting) amount.
///   r is the per-second drip/decay rate.
///   t is the number of elapsed seconds.
/// A and p should be expressed as 18 decimal numbers, e.g to calculate the 
/// @param _a 18 decimal precision uint256 expressing the final amount.
/// @param _p 18 decimal precision uint256 expressing the principal. 
/// @param _t uint256 expressing the time in seconds. 
/// @return _r 18 decimal precision uint256 expressing the decay rate in seconds.
function calculateDripDecayRate(uint256 _a, uint256 _p, uint256 _t) pure returns (uint256 _r) {
  require(_a <= _p, "Final amount must be less than or equal to principal.");
  require(_a <= MAX_INT256, "_a must be smaller than type(int256).max");
  require(_p <= MAX_INT256, "_p must be smaller than type(int256).max");
  require(_t <= MAX_INT256, "_t must be smaller than type(int256).max");

  // Let 1 - r = x, then (ln(A) - ln(p))/t = ln(x)
  int256 _lnX = (FixedPointMathLib.lnWad(int256(_a)) - FixedPointMathLib.lnWad(int256(_p))) / int256(_t);
  int256 _x = FixedPointMathLib.expWad(_lnX);
  require(_x >= 0, "_x must be >= 0");
  _r = 1e18 - uint256(_x);
}