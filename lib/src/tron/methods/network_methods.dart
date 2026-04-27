/// Network and chain information methods for the Tron HTTP API.
///
/// Provides access to chain parameters, node information, energy/bandwidth
/// pricing, and burn statistics. All endpoints use HTTP GET requests.
///
/// ```dart
/// // Typically mixed into TronHttpClient:
/// final params = await client.getChainParameters();
/// final energyPrices = await client.getEnergyPrices();
/// ```
library;

import '../models/tron_chain_parameters.dart';
import '../models/tron_node_info.dart';
import '../../core/rest_transport.dart';

/// Mixin providing 6 Tron network information endpoints (TRON-57 ~ TRON-62).
///
/// All methods use GET requests — these are read-only informational endpoints
/// that do not require request bodies.
mixin TronNetworkMethods {
  /// The REST transport used to send HTTP requests.
  RestTransport get transport;

  /// Returns the current chain configuration parameters.
  ///
  /// Endpoint: `GET /wallet/getchainparameters`
  ///
  /// The response contains a list of key-value pairs representing
  /// network-wide settings such as energy costs, bandwidth limits,
  /// and proposal-activated features.
  ///
  /// ```dart
  /// final params = await client.getChainParameters();
  /// for (final p in params.parameters) {
  ///   print('${p.key}: ${p.value}');
  /// }
  /// ```
  Future<TronChainParameters> getChainParameters() async {
    final result = await transport.get('/wallet/getchainparameters');
    return TronChainParameters.fromJson(result);
  }

  /// Returns information about the connected full node.
  ///
  /// Endpoint: `GET /wallet/getnodeinfo`
  ///
  /// Includes sync status, peer connection counts, and machine/config
  /// details of the node being queried.
  ///
  /// ```dart
  /// final info = await client.getNodeInfo();
  /// print('Connections: ${info.currentConnectCount}');
  /// ```
  Future<TronNodeInfo> getNodeInfo() async {
    final result = await transport.get('/wallet/getnodeinfo');
    return TronNodeInfo.fromJson(result);
  }

  /// Returns a list of nodes connected to the network.
  ///
  /// Endpoint: `GET /wallet/listnodes`
  ///
  /// Each entry contains address information (host and port) for a
  /// connected peer node.
  ///
  /// Returns an empty list if no nodes are reported.
  Future<List<Map<String, dynamic>>> listNodes() async {
    final result = await transport.get('/wallet/listnodes');
    final nodes = result['nodes'] as List? ?? [];
    return nodes.cast<Map<String, dynamic>>();
  }

  /// Returns historical energy prices as a comma-separated string.
  ///
  /// Endpoint: `GET /wallet/getenergyprices`
  ///
  /// Format: `"blockNum:price,blockNum:price,..."` where each entry
  /// represents the energy price (in sun) starting from that block number.
  ///
  /// ```dart
  /// final prices = await client.getEnergyPrices();
  /// // "0:100,13000000:280,..."
  /// ```
  Future<String> getEnergyPrices() async {
    final result = await transport.get('/wallet/getenergyprices');
    return result['prices'] as String? ?? '';
  }

  /// Returns historical bandwidth prices as a comma-separated string.
  ///
  /// Endpoint: `GET /wallet/getbandwidthprices`
  ///
  /// Format is the same as [getEnergyPrices]: `"blockNum:price,..."`.
  Future<String> getBandwidthPrices() async {
    final result = await transport.get('/wallet/getbandwidthprices');
    return result['prices'] as String? ?? '';
  }

  /// Returns the total amount of TRX burned on the network.
  ///
  /// Endpoint: `GET /wallet/getburntrx`
  ///
  /// The returned [BigInt] represents the cumulative burned TRX in sun
  /// (1 TRX = 1,000,000 sun).
  Future<BigInt> getBurnTrx() async {
    final result = await transport.get('/wallet/getburntrx');
    return BigInt.from(result['burnTrxAmount'] ?? 0);
  }
}
