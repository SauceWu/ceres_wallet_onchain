/// A pure Dart multi-chain RPC SDK covering EVM, Tron, Solana, and Sui.
///
/// This library provides typed RPC clients, unified exception handling,
/// and ABI encoding for interacting with multiple blockchain networks
/// from pure Dart code (no Flutter dependency).
///
/// ## Getting started
///
/// ```dart
/// import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
///
/// final config = RpcClientConfig(
///   baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY',
/// );
/// ```
library ceres_wallet_onchain;

export 'src/core/rpc_exception.dart';
export 'src/core/rpc_logger.dart';
export 'src/core/rpc_client_config.dart';
export 'src/core/rpc_transport.dart';
export 'src/core/json_rpc_transport.dart';
export 'src/core/rest_transport.dart';
export 'src/utils/bigint_utils.dart';

// EVM RPC Client
export 'src/evm/evm_rpc_client.dart';
export 'src/evm/evm_address.dart';
export 'src/evm/eip712/eip191_hasher.dart';
export 'src/evm/eip712/eip712_hasher.dart';
export 'src/evm/eip712/eip712_parser.dart';
export 'src/evm/eip712/eip712_types.dart';

// EVM Response Models
export 'src/evm/models/eth_block.dart';
export 'src/evm/models/eth_transaction.dart';
export 'src/evm/models/eth_transaction_receipt.dart';
export 'src/evm/models/eth_log.dart';
export 'src/evm/models/eth_fee_history.dart';
export 'src/evm/models/eth_proof.dart';
export 'src/evm/models/eth_access_list_result.dart';
export 'src/evm/models/eth_withdrawal.dart';
export 'src/evm/models/access_list_entry.dart';
export 'src/evm/models/eth_sync_status.dart';

// ABI Codec
export 'src/abi/abi.dart';

// Tron HTTP Client
export 'src/tron/tron_http_client.dart';
export 'src/tron/tron_address.dart';
export 'src/tron/tron_error.dart';

// Solana RPC Client
export 'src/solana/solana_rpc_client.dart';
export 'src/solana/solana_address.dart';
export 'src/solana/solana_commitment.dart';
export 'src/solana/codec/alt_resolver.dart';
export 'src/solana/codec/compact_u16.dart';
export 'src/solana/codec/compute_budget.dart';
export 'src/solana/codec/solana_tx_decoder.dart';
export 'src/solana/codec/solana_tx_encoder.dart';
export 'src/solana/codec/solana_tx_types.dart';

// Solana Response Models
export 'src/solana/models/account_balance.dart';
export 'src/solana/models/account_info.dart';
export 'src/solana/models/block_commitment.dart';
export 'src/solana/models/block_production.dart';
export 'src/solana/models/blockhash_result.dart';
export 'src/solana/models/cluster_node.dart';
export 'src/solana/models/epoch_info.dart';
export 'src/solana/models/inflation.dart';
export 'src/solana/models/performance_sample.dart';
export 'src/solana/models/prioritization_fee.dart';
export 'src/solana/models/signature_info.dart';
export 'src/solana/models/signature_status.dart';
export 'src/solana/models/simulate_result.dart';
export 'src/solana/models/snapshot_slot.dart';
export 'src/solana/models/solana_block.dart';
export 'src/solana/models/solana_transaction.dart';
export 'src/solana/models/spl_token_account_data.dart';
export 'src/solana/models/stake_activation.dart';
export 'src/solana/models/supply.dart';
export 'src/solana/models/token_account.dart';
export 'src/solana/models/token_amount.dart';
export 'src/solana/models/token_largest_account.dart';
export 'src/solana/models/transaction_meta.dart';
export 'src/solana/models/vote_account.dart';

// Sui RPC Client
export 'src/sui/sui_rpc_client.dart';
export 'src/sui/sui_address.dart';

// Sui Response Models
export 'src/sui/models/sui_balance.dart';
export 'src/sui/models/sui_checkpoint.dart';
export 'src/sui/models/sui_coin.dart';
export 'src/sui/models/sui_coin_metadata.dart';
export 'src/sui/models/sui_committee_info.dart';
export 'src/sui/models/sui_dry_run_result.dart';
export 'src/sui/models/sui_dynamic_field.dart';
export 'src/sui/models/sui_effects.dart';
export 'src/sui/models/sui_event.dart';
export 'src/sui/models/sui_gas_cost_summary.dart';
export 'src/sui/models/sui_move_module.dart';
export 'src/sui/models/sui_object_change.dart';
export 'src/sui/models/sui_object_data.dart';
export 'src/sui/models/sui_object_owner.dart';
export 'src/sui/models/sui_object_response.dart';
export 'src/sui/models/sui_options.dart';
export 'src/sui/models/sui_paginated.dart';
export 'src/sui/models/sui_protocol_config.dart';
export 'src/sui/models/sui_stake.dart';
export 'src/sui/models/sui_system_state.dart';
export 'src/sui/models/sui_transaction_block_response.dart';
export 'src/sui/models/sui_validators_apy.dart';

// Tron Response Models
export 'src/tron/models/tron_account.dart';
export 'src/tron/models/tron_block.dart';
export 'src/tron/models/tron_transaction.dart';
export 'src/tron/models/tron_transaction_info.dart';
export 'src/tron/models/tron_account_resource.dart';
export 'src/tron/models/tron_trigger_result.dart';
export 'src/tron/models/tron_broadcast_result.dart';
export 'src/tron/models/tron_witness.dart';
export 'src/tron/models/tron_asset_issue.dart';
export 'src/tron/models/tron_chain_parameters.dart';
export 'src/tron/models/tron_node_info.dart';
