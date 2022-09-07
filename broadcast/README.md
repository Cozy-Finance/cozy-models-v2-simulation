# Deploys

This file contains a list of live deployments.
These are also stored in this folder under e.g. `broadcast/DeployModelFactories.s.sol/10/run-latest.json`, but documenting them here as well is more user-friendly.
Deploys are sorted by timestamp, with the most recent one first.

## Optimism

### Model Factories

#### Deploy 1

CostModelJumpRateFactory deployed 0xF6660966f9A20259396d1A1674fC2DD1773a1C73

DecayModelConstantFactory deployed 0xF049CE89083C67A30eD6172E94F9fBd8FE76483E

DripModelConstantFactory deployed 0x1D369C7bD2C6389fdF1d55F9b8C24d610b811856

<details>
  <summary>Metadata</summary>

  - Timestamp: 1662563047
  - Parsed timestamp: 2022-09-07T15:04:07.000Z
  - Commit: baa1ce2aab4b9910c0986eabae07387b1d3bfa3c
</details>
<br />

### CostModelJumpRate

#### Deploy 1

CostModelJumpRateFactory deployed 0x7e5a2bDC10F05D6cF15563570Eae3B8d346B9991

<details>
  <summary>Metadata</summary>

  - Timestamp: 1662572225
  - Parsed timestamp: 2022-09-07T17:37:05.000Z
  - Commit: 5e56fff0861d324a45c680226809fc34c764f088
</details>
<details>
  <summary>Configuration</summary>

  - factory 0xF6660966f9A20259396d1A1674fC2DD1773a1C73
  - kink 800000000000000000
  - costFactorAtZeroUtilization 0
  - costFactorAtKinkUtilization 200000000000000000
  - costFactorAtFullUtilization 500000000000000000
  - cancellationPenalty 100000000000000000
</details>
<br />

### DecayModelConstant

#### Deploy 1

DecayModelConstant deployed 0x09f20eA12fe5a1211A0485aa59C067E9fcC4c04A

<details>
  <summary>Metadata</summary>

  - Timestamp: 1662572693
  - Parsed timestamp: 2022-09-07T17:44:53.000Z
  - Commit: 5e56fff0861d324a45c680226809fc34c764f088
</details>
<details>
  <summary>Configuration</summary>

  - factory 0xF049CE89083C67A30eD6172E94F9fBd8FE76483E
  - decayRatePerSecond 9116094774
</details>
<br />

### DripModelConstant

#### Deploy 1

DripModelConstant deployed 0xEf778611eAf2e624432F49bcF7AC433584f642a2

<details>
  <summary>Metadata</summary>

  - Timestamp: 1662573097
  - Parsed timestamp: 2022-09-07T17:51:37.000Z
  - Commit: 5e56fff0861d324a45c680226809fc34c764f088
</details>
<details>
  <summary>Configuration</summary>

  - factory 0x1D369C7bD2C6389fdF1d55F9b8C24d610b811856
  - dripRatePerSecond 9116094774
</details>
<br />