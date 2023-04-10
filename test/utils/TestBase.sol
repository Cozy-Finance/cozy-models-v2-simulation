// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
  function _randomAddress() internal view returns (address payable) {
    return payable(address(uint160(_randomUint256())));
  }

  function _randomBytes32() internal view returns (bytes32) {
    return keccak256(
      abi.encode(block.timestamp, blockhash(0), gasleft(), tx.origin, keccak256(msg.data), address(this).codehash)
    );
  }

  function _randomUint256() internal view returns (uint256) {
    return uint256(_randomBytes32());
  }
}
