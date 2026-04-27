## 0.1.1

- EIP-712/191 hashing layer (EIP712Parser, EIP712Hasher, EIP191Hasher)
- Solana transaction wire codec (SolanaTxDecoder, SolanaTxEncoder, compact-u16)
- AltResolver: v0 transaction address lookup table resolution with concurrent fetching
- ComputeBudgetDecoder: all 4 ComputeBudget instruction variants
- Fix: AltResolver crash on empty AccountInfo.data (WR-01)
- Fix: EIP712Hasher now treats absent optional fields as zero values, matching ethers.js behavior (WR-02)

## 0.1.0

- Initial release
- EVM RPC client with 49 typed methods (eth_, net_, web3_ namespaces)
- Tron HTTP client with 65 typed endpoints
- Solana RPC client with 50 typed methods
- Sui RPC client with 39 typed methods (sui_ and suix_ namespaces)
- Complete ABI encoder/decoder (address, uint, bool, bytes, string, tuple, arrays)
- Function selector computation via keccak256
- Unified RPC exception model with retry support
- Pure Dart -- no Flutter dependency
