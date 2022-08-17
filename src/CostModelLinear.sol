// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "cozy-v2-interfaces/interfaces/ICostModel.sol";

/**
 * @notice A naive linear cost model, where the cost is simply 10% of the new utilization of the market.
 * @dev This is used for tests, and should not be used for a real market.
 */
contract CostModelLinear is ICostModel {
  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 utilization, uint256 newUtilization) external pure returns (uint256) {
    utilization; // Suppress unused variable warning.
    return newUtilization / 10; // Cost is 10% of the new utilization.
  }

  /// @notice Gives the return value in assets of returning protection as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 utilization, uint256 newUtilization) external pure returns (uint256) {
    newUtilization; // Suppress unused variable warning.
    return utilization / 10; // Return is 10% of the current utilization.
  }
}
