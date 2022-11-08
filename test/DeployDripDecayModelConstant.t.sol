// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "script/DeployDripDecayModelConstant.s.sol";
import "forge-std/Test.sol";

contract DeployDripDecayModelConstantHarness is DeployDripDecayModelConstant {
  function exposed_calculateDripDecayRate(uint256 _a, uint256 _p, uint256 _t) public view returns (uint256 _r) {
    return calculateDripDecayRate(_a, _p, _t);
  }
}

contract DeployDripDecayModelConstantTest is Test {
  uint256 constant WAD = 1e18;
  uint256 constant SECONDS_IN_YEAR = 31557600;
  uint256 constant SECONDS_30_DAYS = 2592000;

  DeployDripDecayModelConstantHarness testHarness;

  function setUp() public {
    testHarness = new DeployDripDecayModelConstantHarness();
  }

  function test_calculateDripDecayRate_25Percent() public {
    assertEq(testHarness.exposed_calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_IN_YEAR), 9116094733); 
    assertEq(testHarness.exposed_calculateDripDecayRate(750000 * WAD, 1000000 * WAD, SECONDS_IN_YEAR), 9116094733); 
    assertEq(testHarness.exposed_calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_IN_YEAR), 9116094733); 

    assertEq(testHarness.exposed_calculateDripDecayRate(75 * WAD, 100 * WAD, SECONDS_30_DAYS), 110988447719); 
    assertEq(testHarness.exposed_calculateDripDecayRate(750000 * WAD, 1000000 * WAD, SECONDS_30_DAYS), 110988447719); 
    assertEq(testHarness.exposed_calculateDripDecayRate(30 * WAD, 40 * WAD, SECONDS_30_DAYS), 110988447719); 
  }

  function test_calculateDripDecayRate_50Percent() public {
    assertEq(testHarness.exposed_calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_IN_YEAR), 21964508484); 
    assertEq(testHarness.exposed_calculateDripDecayRate(500000 * WAD, 1000000 * WAD, SECONDS_IN_YEAR), 21964508484); 
    assertEq(testHarness.exposed_calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_IN_YEAR), 21964508484); 

    assertEq(testHarness.exposed_calculateDripDecayRate(50 * WAD, 100 * WAD, SECONDS_30_DAYS), 267417857978); 
    assertEq(testHarness.exposed_calculateDripDecayRate(500000 * WAD, 1000000 * WAD, SECONDS_30_DAYS), 267417857978); 
    assertEq(testHarness.exposed_calculateDripDecayRate(20 * WAD, 40 * WAD, SECONDS_30_DAYS), 267417857978); 
  }
}