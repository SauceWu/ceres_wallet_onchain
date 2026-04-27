import '../models/eth_log.dart';
import '../../core/json_rpc_transport.dart';

/// Mixin providing Ethereum filter-based RPC methods.
///
/// Filters allow polling for new blocks, pending transactions, or log
/// events without re-querying the full history each time.
///
/// Requires [transport] to be provided by the implementing class.
///
/// ```dart
/// class MyClient with EvmFilterMethods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmFilterMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Creates a new log filter on the node.
  ///
  /// Sends `eth_newFilter` with [filterParams] and returns the filter ID
  /// string. Use [getFilterChanges] or [getFilterLogs] to poll for results.
  ///
  /// The [filterParams] map accepts the same fields as `eth_getLogs`:
  /// `fromBlock`, `toBlock`, `address`, `topics`.
  Future<String> newFilter(Map<String, dynamic> filterParams) async {
    final result = await transport.send('eth_newFilter', [filterParams]);
    return result as String;
  }

  /// Creates a filter for new block hashes.
  ///
  /// Sends `eth_newBlockFilter` and returns the filter ID string.
  /// Poll with [getFilterChanges] to receive new block hashes.
  Future<String> newBlockFilter() async {
    final result = await transport.send('eth_newBlockFilter');
    return result as String;
  }

  /// Creates a filter for pending transaction hashes.
  ///
  /// Sends `eth_newPendingTransactionFilter` and returns the filter ID
  /// string. Poll with [getFilterChanges] to receive pending tx hashes.
  Future<String> newPendingTransactionFilter() async {
    final result = await transport.send('eth_newPendingTransactionFilter');
    return result as String;
  }

  /// Returns changes since last poll for the given [filterId].
  ///
  /// Sends `eth_getFilterChanges` with [filterId]. The return type is
  /// `List<dynamic>` because the response is polymorphic:
  /// - For log filters: list of log JSON objects
  /// - For block/tx filters: list of hash strings
  ///
  /// Callers should check the filter type and cast accordingly.
  Future<List<dynamic>> getFilterChanges(String filterId) async {
    final result = await transport.send('eth_getFilterChanges', [filterId]);
    return (result as List<dynamic>);
  }

  /// Returns all logs matching the filter with the given [filterId].
  ///
  /// Sends `eth_getFilterLogs` and parses each result into an [EthLog].
  /// Only works for log filters (created via [newFilter]).
  Future<List<EthLog>> getFilterLogs(String filterId) async {
    final result = await transport.send('eth_getFilterLogs', [filterId]);
    final list = result as List<dynamic>;
    return list.map((e) => EthLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Uninstalls a filter with the given [filterId].
  ///
  /// Sends `eth_uninstallFilter` and returns `true` if the filter was
  /// successfully removed, `false` otherwise. Filters that have not been
  /// polled for a period are automatically removed by the node.
  Future<bool> uninstallFilter(String filterId) async {
    final result = await transport.send('eth_uninstallFilter', [filterId]);
    return result as bool;
  }
}
