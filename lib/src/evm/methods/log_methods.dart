import '../models/eth_log.dart';
import '../../core/json_rpc_transport.dart';

/// Mixin providing Ethereum log query RPC methods.
///
/// Requires [transport] to be provided by the implementing class.
///
/// ```dart
/// class MyClient with EvmLogMethods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmLogMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns logs matching the given [filterParams].
  ///
  /// Sends `eth_getLogs` with [filterParams] and parses each result
  /// into an [EthLog].
  ///
  /// The [filterParams] map typically contains:
  /// - `fromBlock` (String): block number or tag (`"earliest"`, `"latest"`)
  /// - `toBlock` (String): block number or tag
  /// - `address` (String or List<String>): contract address(es) to filter
  /// - `topics` (List): indexed event topics, with `null` for wildcards
  ///
  /// Example:
  /// ```dart
  /// final logs = await client.getLogs({
  ///   'fromBlock': '0x0',
  ///   'toBlock': 'latest',
  ///   'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
  /// });
  /// ```
  Future<List<EthLog>> getLogs(Map<String, dynamic> filterParams) async {
    final result = await transport.send('eth_getLogs', [filterParams]);
    final list = result as List<dynamic>;
    return list.map((e) => EthLog.fromJson(e as Map<String, dynamic>)).toList();
  }
}
