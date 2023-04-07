// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "src/lib/ExponentialDecay.sol";
import "forge-std/Test.sol";

contract ExponentialDecay is Test {
  uint256 constant WAD = 1e18;
  uint256 constant SECONDS_IN_YEAR = 31_557_600;
  uint256 constant SECONDS_30_DAYS = 2_592_000;

  function test_calculateDripDecayRate_25Percent() public {
    assertEq(calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_IN_YEAR), 9_116_094_733);
    assertEq(calculateDripDecayRate(750_000 * WAD, 1_000_000 * WAD, SECONDS_IN_YEAR), 9_116_094_733);
    assertEq(calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_IN_YEAR), 9_116_094_733);

    assertEq(calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_30_DAYS), 110_988_447_719);
    assertEq(calculateDripDecayRate(750_000 * WAD, 1_000_000 * WAD, SECONDS_30_DAYS), 110_988_447_719);
    assertEq(calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_30_DAYS), 110_988_447_719);
  }

  function test_calculateDripDecayRate_50Percent() public {
    assertEq(calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_IN_YEAR), 21_964_508_484);
    assertEq(calculateDripDecayRate(500_000 * WAD, 1_000_000 * WAD, SECONDS_IN_YEAR), 21_964_508_484);
    assertEq(calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_IN_YEAR), 21_964_508_484);

    assertEq(calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_30_DAYS), 267_417_857_978);
    assertEq(calculateDripDecayRate(500_000 * WAD, 1_000_000 * WAD, SECONDS_30_DAYS), 267_417_857_978);
    assertEq(calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_30_DAYS), 267_417_857_978);
  }
}
