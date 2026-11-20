import 'package:flutter/services.dart';

import 'coastlines.dart';
import 'network.dart';

/// Loads and caches the parsed `Network` instances (for 0, 1, and 2 max connections)
/// and `CoastlineData` from `assets/flights.tsv` and `assets/coastlines.bin`.
class FlightsRepository {
  FlightsRepository({
    required this.rawFlightsTsv,
    required this.coastlines,
  });

  final String rawFlightsTsv;
  final CoastlineData coastlines;
  final List<Network?> _networks = List<Network?>.filled(
    maxConnectionsLimit + 1,
    null,
  );

  Network network(int maxConnections) {
    final limit = maxConnections.clamp(0, maxConnectionsLimit);
    final existing = _networks[limit];
    if (existing != null) return existing;
    final parsed = Network.parse(rawFlightsTsv, limit);
    _networks[limit] = parsed;
    return parsed;
  }

  static Future<FlightsRepository> loadFromAssets() async {
    final tsvFuture = rootBundle.loadString('assets/flights.tsv');
    final coastFuture = rootBundle.load('assets/coastlines.bin');
    final tsv = await tsvFuture;
    final coastData = await coastFuture;
    final bytes = coastData.buffer.asUint8List(
      coastData.offsetInBytes,
      coastData.lengthInBytes,
    );
    final coastlines = CoastlineData.parse(bytes);
    final repo = FlightsRepository(
      rawFlightsTsv: tsv,
      coastlines: coastlines,
    );
    // Pre-warm standard 1-connection network
    repo.network(standardConnections);
    return repo;
  }
}
