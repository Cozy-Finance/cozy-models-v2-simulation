// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "src/lib/ExponentialDecay.sol";
import "forge-std/Test.sol";

contract ExponentialDecay is Test {
  uint256 constant WAD = 1e18;
  uint256 constant SECONDS_IN_YEAR = 31557600;
  uint256 constant SECONDS_30_DAYS = 2592000;

  function test_calculateDripDecayRate_25Percent() public {
    assertEq(calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_IN_YEAR), 9116094733); 
    assertEq(calculateDripDecayRate(750000 * WAD, 1000000 * WAD, SECONDS_IN_YEAR), 9116094733); 
    assertEq(calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_IN_YEAR), 9116094733); 

    assertEq(calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_30_DAYS), 110988447719); 
    assertEq(calculateDripDecayRate(750000 * WAD, 1000000 * WAD, SECONDS_30_DAYS), 110988447719); 
    assertEq(calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_30_DAYS), 110988447719); 
  }

  function test_calculateDripDecayRate_50Percent() public {
    assertEq(calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_IN_YEAR), 21964508484); 
    assertEq(calculateDripDecayRate(500000 * WAD, 1000000 * WAD, SECONDS_IN_YEAR), 21964508484); 
    assertEq(calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_IN_YEAR), 21964508484); 

    assertEq(calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_30_DAYS), 267417857978); 
    assertEq(calculateDripDecayRate(500000 * WAD, 1000000 * WAD, SECONDS_30_DAYS), 267417857978); 
    assertEq(calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_30_DAYS), 267417857978); 
  }
}