# SUI Swap Marketplace

A decentralized token swap protocol built on the SUI blockchain, implementing an Automated Market Maker (AMM) for token pairs. This project allows users to create liquidity pools, add liquidity, and swap tokens (e.g., SUI and custom COIN) on the SUI testnet.

## Features
- **Create Pool**: Initialize a liquidity pool for a token pair (e.g., SUI/COIN).
- **Add Liquidity**: Provide tokens to a pool and receive liquidity tokens.
- **Swap Tokens**: Swap tokens (e.g., SUI to COIN or vice versa) using AMM logic.
- **Remove Liquidity**: Withdraw tokens from a pool based on liquidity share.
- **Safe Math**: Handles overflow and type safety for robust operation.

## Prerequisites
- **SUI CLI**: Install the SUI command-line interface. Follow [SUI Installation Guide](https://docs.sui.io/guides/developer/getting-started/sui-install).
- **Testnet SUI**: Get testnet SUI tokens via `sui client faucet`.
- **Rust**: Required for SUI CLI (included in installation).
- **Node.js** (optional): For integrating with a JavaScript SDK.

## Installation
1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd swapMarketPlace
   ```
2. **Check Move.toml**:
   Ensure `Move.toml` includes dependencies and addresses:
   ```toml
   [package]
   name = "swapMarketPlace"
   edition = "2024.beta"

   [dependencies]
   Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }

   [addresses]
   swap = "0x0"
   swapmarketplace = "0x0"
   ```

3. **Build Project**:
   ```bash
   sui move build
   ```

## Deployment
1. **Publish to Testnet**:
   ```bash
   sui client publish --gas-budget 100000000
   ```
   - Save the `<NEW_PACKAGE_ID>` from the output.
   - Note: Republish if the `token_swap.move` code changes.

2. **Create a Pool** (SUI/COIN):
   ```bash
   sui client call \
     --package <NEW_PACKAGE_ID> \
     --module token_swap \
     --function create_pool \
     --type-args 0x2::sui::SUI 0x4a54e1f68f8572e2130b955b756f5a73a33911c04934515cbe92a19e643f04c5::coin::COIN \
     --gas-budget 10000000
   ```
   - Save `<POOL_ID>` from the output.

3. **Mint COIN** (if needed):
   ```bash
   sui client call \
     --package 0x4a54e1f68f8572e2130b955b756f5a73a33911c04934515cbe92a19e643f04c5 \
     --module coin \
     --function mint \
     --args <TREASURY_CAP_ID> 1000000000 <YOUR_ADDRESS> \
     --gas-budget 10000000
   ```

## Usage
### Add Liquidity
Add SUI and COIN to the pool:
```bash
sui client coins --coin-type 0x2::sui::SUI
sui client coins --coin-type 0x4a54e1f68f8572e2130b955b756f5a73a33911c04934515cbe92a19e643f04c5::coin::COIN
```
```bash
sui client call \
  --package <NEW_PACKAGE_ID> \
  --module token_swap \
  --function add_liquidity \
  --type-args 0x2::sui::SUI 0x4a54e1f68f8572e2130b955b756f5a73a33911c04934515cbe92a19e643f04c5::coin::COIN \
  --args <POOL_ID> <SUI_COIN_OBJECT_ID> <COIN_OBJECT_ID> \
  --gas-budget 50000000
```
- Note: Ensure coin amounts match the pool's reserve ratio (if not empty).

### Swap SUI to COIN
Swap SUI for COIN:
```bash
sui client call \
  --package <NEW_PACKAGE_ID> \
  --module token_swap \
  --function swap_a_to_b \
  --type-args 0x2::sui::SUI 0x4a54e1f68f8572e2130b955b756f5a73a33911c04934515cbe92a19e643f04c5::coin::COIN \
  --args <POOL_ID> <SUI_COIN_OBJECT_ID> 1000000 \
  --gas-budget 50000000
```
- `<SUI_COIN_OBJECT_ID>`: Coin with sufficient balance.
- `1000000`: Minimum COIN to receive (adjust to avoid slippage errors).

### Check Pool State
```bash
sui client object <POOL_ID>
```
- Verify `balance_a` (SUI) and `balance_b` (COIN) after transactions.

## Testing
Run unit tests for Move code:
```bash
sui move test
```
- Add test cases in `token_swap.move` under `#[test_only]` module to validate `create_pool`, `add_liquidity`, and `swap_a_to_b`.

## Troubleshooting
- **TypeMismatch**: Ensure `<POOL_ID>` and coin IDs match the correct types.
- **InsufficientBalance**: Check pool reserves (`balance_b > 0`) or coin balance.
- **Overflow**: Use reasonable coin amounts to avoid `u64` overflow.
- **Gas Errors**: Increase `--gas-budget` (e.g., `100000000`).
- **Invalid Pool**: Recreate pool if package is republished.

## Future Improvements
- Add slippage protection for swaps.
- Support dynamic fee structures.
- Integrate with a frontend (ReactJS SDK) for user interaction.
- Add events for better transaction tracking.

## Contributing
Contributions are welcome! Submit issues or pull requests to enhance the protocol.

## License
MIT License