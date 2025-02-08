# Decentralized Stablecoin Project

A minimal stablecoin implementation that is exogenous (backed by WETH and WBTC) and pegged to the USD. This project demonstrates a simplified version of protocols like DAI, but without governance, fees, and with only WETH and WBTC as collateral.

## Overview

This stablecoin system is:

- Collateral: Exogenous (ETH, BTC)
- Peg: Algorithmic (Pegged to USD)
- Stability: Over-collateralized

The system is designed to maintain 1 DSC (Decentralized Stable Coin) = $1 USD peg through over-collateralization. The minimum collateral ratio is 200%, meaning users must deposit at least $200 worth of collateral to mint $100 DSC.

## Key Components

1. **DecentralizedStableCoin.sol**

   - ERC20 token implementation
   - Handles minting and burning of DSC
   - Controlled by DSCEngine

2. **DSCEngine.sol**

   - Core protocol logic
   - Manages collateral deposits and withdrawals
   - Controls DSC minting and burning
   - Handles liquidations
   - Maintains system health and stability

3. **OracleLib.sol**
   - Chainlink price feed wrapper
   - Ensures fresh price data
   - System freezes if price data becomes stale

## Features

- Deposit collateral (WETH, WBTC)
- Mint DSC against collateral
- Burn DSC to redeem collateral
- Liquidate unsafe positions
- View system health metrics

## Quick Start

1. Install dependencies:

```bash
forge install
```

2. Run tests:

```bash
forge test
```

3. Deploy:

```bash
forge script script/DeployDSC.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Testing

The project includes:

- Unit tests
- Fuzz tests
- Invariant tests

Key invariants tested:

1. The total value of collateral should always be greater than total DSC supply
2. Protocol's getter functions should never revert

## Contract Architecture

```
src/
├── DSCEngine.sol        # Main protocol logic
├── DecentralizedStableCoin.sol  # ERC20 token
└── libraries/
    └── OracleLib.sol    # Price feed wrapper
```

## Key Functions

### DSCEngine

- `depositCollateral`: Deposit WETH or WBTC as collateral
- `mintDsc`: Create new DSC tokens against deposited collateral
- `burnDsc`: Destroy DSC tokens
- `redeemCollateral`: Withdraw collateral
- `liquidate`: Liquidate unsafe positions
- `getHealthFactor`: Check position safety

### DecentralizedStableCoin

- `mint`: Create new DSC tokens (only DSCEngine)
- `burn`: Destroy DSC tokens (only DSCEngine)

## Security Considerations

1. Over-collateralization requirements
2. Liquidation thresholds
3. Oracle safety checks
4. Reentrancy protection
5. Access control

## Development Environment

- Foundry for testing and deployment
- Chainlink price feeds for oracle data
- OpenZeppelin contracts for standard implementations

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License.
