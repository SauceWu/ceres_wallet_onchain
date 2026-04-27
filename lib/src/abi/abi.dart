/// ABI encoding and decoding for Solidity contracts.
///
/// This module provides complete ABI codec support including:
/// - [AbiCoder]: top-level encode/decode API
/// - [AbiParam]: type descriptors for parameters
/// - [FunctionSelector]: 4-byte function selector computation
/// - Individual type coders for all supported Solidity types
library;

export 'abi_type.dart';
export 'abi_param.dart';
export 'abi_type_coder.dart';
export 'abi_coder.dart';
export 'function_selector.dart';
export 'coders/number_coder.dart';
export 'coders/bool_coder.dart';
export 'coders/address_coder.dart';
export 'coders/fixed_bytes_coder.dart';
export 'coders/dynamic_bytes_coder.dart';
export 'coders/string_coder.dart';
export 'coders/tuple_coder.dart';
export 'coders/array_coder.dart';
