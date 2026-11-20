import 'dart:collection';
import 'dart:math' as math;

import 'coastlines.dart';
import 'fastrand.dart';

const int maxConnectionsLimit = 2;
const int standardConnections = 1;
const double _earthRadiusNm = 3440.065;
const int _puzzleAttempts = 10000;
const int _endAttempts = 8;
const int _onceSearchLimit = 200000;

/// The hops a puzzle's shortest route may take: at least `min`, at most `max` (`null`: no limit).
class HopRange {
  const HopRange({this.min = 0, this.max});

  final int min;
  final int? max;

  bool contains(int hops) => hops >= min && (max == null || hops <= max!);
}

/// An itinerary for a hop: where it connects, in flying order, and its total length in nautical miles.
class Ticket {
  const Ticket({required this.via, required this.distance});

  final List<int> via;
  final double distance;
}

/// One move: a ticket from an airport to one whose code is one letter different.
class Hop {
  const Hop({
    required this.to,
    required this.via,
    required this.distance,
    required this.spare,
  });

  final int to;
  final List<int> via;
  final double distance;
  final List<Ticket> spare;

  Ticket ticket() => Ticket(via: via, distance: distance);

  Ticket? ticketAvoiding(bool Function(int) used) {
    if (!via.any(used)) {
      return ticket();
    }
    for (final t in spare) {
      if (!t.via.any(used)) {
        return t;
      }
    }
    return null;
  }
}

/// A route found where each airport is used once (`Network.routesOnce`).
class OnceRoute {
  const OnceRoute({
    required this.distance,
    required this.stops,
    required this.legs,
  });

  final double distance;
  final List<int> stops;
  final List<Ticket> legs;
}

/// Great-circle distance in nautical miles between two `(lat, lon)` points (haversine).
double greatCircleNm(LatLon a, LatLon b) {
  final lat1 = a.lat * math.pi / 180.0;
  final lon1 = a.lon * math.pi / 180.0;
  final lat2 = b.lat * math.pi / 180.0;
  final lon2 = b.lon * math.pi / 180.0;
  final sinLat = math.sin((lat2 - lat1) / 2.0);
  final sinLon = math.sin((lon2 - lon1) / 2.0);
  final h = sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
  return 2.0 * _earthRadiusNm * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Number of positions at which two 3-letter codes differ.
int lettersApart(String a, String b) {
  var diff = 0;
  final len = math.min(a.length, b.length);
  for (var i = 0; i < len; i++) {
    if (a.codeUnitAt(i) != b.codeUnitAt(i)) diff++;
  }
  return diff;
}

class _HeapEntry {
  const _HeapEntry(this.dist, this.node);
  final double dist;
  final int node;

  int compareTo(_HeapEntry other) {
    final c = dist.compareTo(other.dist);
    return c != 0 ? c : node.compareTo(other.node);
  }
}

class _MinHeap {
  final List<_HeapEntry> _data = <_HeapEntry>[];

  bool get isNotEmpty => _data.isNotEmpty;

  void add(_HeapEntry entry) {
    _data.add(entry);
    _siftUp(_data.length - 1);
  }

  _HeapEntry removeFirst() {
    final first = _data.first;
    final last = _data.removeLast();
    if (_data.isNotEmpty) {
      _data[0] = last;
      _siftDown(0);
    }
    return first;
  }

  void _siftUp(int idx) {
    var i = idx;
    final item = _data[i];
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (item.compareTo(_data[parent]) >= 0) break;
      _data[i] = _data[parent];
      i = parent;
    }
    _data[i] = item;
  }

  void _siftDown(int idx) {
    var i = idx;
    final len = _data.length;
    final item = _data[i];
    final half = len >> 1;
    while (i < half) {
      var child = (i << 1) + 1;
      final right = child + 1;
      if (right < len && _data[right].compareTo(_data[child]) < 0) {
        child = right;
      }
      if (item.compareTo(_data[child]) <= 0) break;
      _data[i] = _data[child];
      i = child;
    }
    _data[i] = item;
  }
}

class _PartialRoute {
  const _PartialRoute({
    required this.at,
    required this.from,
    required this.ticket,
    required this.soFar,
  });

  final int at;
  final int from;
  final Ticket? ticket;
  final double soFar;
}

class _RawRoute {
  const _RawRoute({
    required this.a,
    required this.b,
    required this.best,
    required this.others,
    required this.lineNum,
  });

  final String a;
  final String b;
  final String best;
  final List<String> others;
  final int lineNum;
}

/// The playable airport network for a given `maxConnections` (0, 1, or 2),
/// faithfully ported from `jotto-cli/src/flights/data.rs`.
class Network {
  Network._({
    required this.maxConnections,
    required List<String> codes,
    required List<LatLon> coords,
    required List<(String, String)> places,
    required List<List<Hop>> adj,
    required Set<int> bridges,
    required List<(int, int)> puzzleCounts,
  })  : _codes = codes,
        _coords = coords,
        _places = places,
        _adj = adj,
        _bridges = bridges,
        _puzzleCounts = puzzleCounts;

  final int maxConnections;
  final List<String> _codes;
  final List<LatLon> _coords;
  final List<(String, String)> _places;
  final List<List<Hop>> _adj;
  final Set<int> _bridges;
  final List<(int, int)> _puzzleCounts;

  int get length => _codes.length;
  bool get isEmpty => _codes.isEmpty;
  int get bridgeCount => _bridges.length;

  int hopCount() {
    var sum = 0;
    for (final list in _adj) {
      sum += list.length;
    }
    return sum ~/ 2;
  }

  String code(int idx) => _codes[idx];

  String place(int idx) {
    final (city, country) = _places[idx];
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    return country;
  }

  LatLon coords(int idx) => _coords[idx];

  int? indexOf(String target) {
    var low = 0;
    var high = _codes.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final c = _codes[mid].compareTo(target);
      if (c < 0) {
        low = mid + 1;
      } else if (c > 0) {
        high = mid - 1;
      } else {
        return mid;
      }
    }
    return null;
  }

  List<Hop> hops(int idx) => _adj[idx];

  Hop? hop(int a, int b) {
    final list = _adj[a];
    var low = 0;
    var high = list.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final midVal = list[mid].to;
      if (midVal < b) {
        low = mid + 1;
      } else if (midVal > b) {
        high = mid - 1;
      } else {
        return list[mid];
      }
    }
    return null;
  }

  static int _edgeKey(int a, int b) {
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    return (lo << 20) | hi;
  }

  bool _isBridge(int a, int b) => _bridges.contains(_edgeKey(a, b));

  List<double> _dijkstra(
    int source,
    int? stop,
    void Function(int from, int to) improved,
  ) {
    final dist = List<double>.filled(length, double.infinity);
    final heap = _MinHeap();
    dist[source] = 0.0;
    heap.add(_HeapEntry(0.0, source));

    while (heap.isNotEmpty) {
      final entry = heap.removeFirst();
      final d = entry.dist;
      final node = entry.node;
      if (stop != null && node == stop) {
        break;
      }
      if (d > dist[node]) {
        continue;
      }
      for (final h in _adj[node]) {
        final nd = d + h.distance;
        if (nd < dist[h.to]) {
          dist[h.to] = nd;
          improved(node, h.to);
          heap.add(_HeapEntry(nd, h.to));
        }
      }
    }
    return dist;
  }

  /// Shortest route from `start` to `end` by total distance in nautical miles.
  (double, List<int>)? shortest(int start, int end) {
    final prev = List<int>.filled(length, -1);
    final dist = _dijkstra(start, end, (from, to) => prev[to] = from);
    if (!dist[end].isFinite) {
      return null;
    }
    final path = <int>[end];
    var cur = end;
    while (cur != start) {
      cur = prev[cur];
      if (cur < 0) return null;
      path.add(cur);
    }
    return (dist[end], path.reversed.toList());
  }

  /// The `want` shortest routes from `start` to `end`, shortest first, when each airport
  /// may be used only once in the whole trip (stops and connections included).
  List<OnceRoute> routesOnce(int start, int end, int want) {
    final toEnd = _dijkstra(end, null, (_, __) {});
    if (!toEnd[start].isFinite) {
      return const [];
    }

    final routes = <_PartialRoute>[
      _PartialRoute(at: start, from: -1, ticket: null, soFar: 0.0),
    ];
    final heap = _MinHeap();
    heap.add(_HeapEntry(toEnd[start], 0));
    final used = List<bool>.filled(length, false);
    final found = <OnceRoute>[];

    void mark(int rIdx, bool on) {
      var r = rIdx;
      while (r != -1) {
        final node = routes[r];
        used[node.at] = on;
        final via = node.ticket?.via;
        if (via != null) {
          for (final c in via) {
            used[c] = on;
          }
        }
        r = node.from;
      }
    }

    while (heap.isNotEmpty) {
      final entry = heap.removeFirst();
      final r = entry.node;
      final current = routes[r];
      final at = current.at;
      final soFar = current.soFar;

      if (at == end) {
        final stops = <int>[];
        final legs = <Ticket>[];
        var i = r;
        while (i != -1) {
          final pr = routes[i];
          stops.add(pr.at);
          if (pr.ticket != null) {
            legs.add(pr.ticket!);
          }
          i = pr.from;
        }
        found.add(
          OnceRoute(
            distance: soFar,
            stops: stops.reversed.toList(),
            legs: legs.reversed.toList(),
          ),
        );
        if (found.length == want) {
          break;
        }
        continue;
      }

      if (routes.length > _onceSearchLimit) {
        break;
      }

      mark(r, true);
      for (final h in _adj[at]) {
        if (used[h.to] || !toEnd[h.to].isFinite) {
          continue;
        }
        final ticket = h.ticketAvoiding((idx) => used[idx]);
        if (ticket != null) {
          final len = soFar + ticket.distance;
          routes.add(
            _PartialRoute(at: h.to, from: r, ticket: ticket, soFar: len),
          );
          heap.add(_HeapEntry(len + toEnd[h.to], routes.length - 1));
        }
      }
      mark(r, false);
    }

    return found;
  }

  bool hasTwoRoutes(int start, int end) {
    final res = shortest(start, end);
    return res != null && _crossesALoop(res.$2);
  }

  bool _crossesALoop(List<int> path) {
    for (var i = 0; i < path.length - 1; i++) {
      if (!_isBridge(path[i], path[i + 1])) {
        return true;
      }
    }
    return false;
  }

  /// Every airport that makes a puzzle with `start` in `range`, in index order.
  List<int> puzzleEnds(int start, HopRange range) {
    final n = length;
    final hops = List<int>.filled(n, 0);
    final two = List<bool>.filled(n, false);
    final dist = _dijkstra(start, null, (from, to) {
      hops[to] = hops[from] + 1;
      two[to] = two[from] || !_isBridge(from, to);
    });
    final startCode = code(start);
    final result = <int>[];
    for (var end = 0; end < n; end++) {
      if (dist[end].isFinite &&
          two[end] &&
          lettersApart(startCode, code(end)) == 3 &&
          range.contains(hops[end])) {
        result.add(end);
      }
    }
    return result;
  }

  int puzzleCount(HopRange range) {
    var total = 0;
    for (final (hops, count) in _puzzleCounts) {
      if (range.contains(hops)) {
        total += count;
      }
    }
    return total;
  }

  bool isValidPuzzle(int start, int end) {
    return lettersApart(code(start), code(end)) == 3 &&
        hasTwoRoutes(start, end);
  }

  /// Draws a random puzzle whose shortest route's hops are in `range`, using the exact same
  /// algorithm and RNG call sequence as `Network::random_puzzle` in `jotto-cli`.
  (int, int)? randomPuzzle(Fastrand rng, HopRange range) {
    if (range.min > 3) {
      final starts = <int>[
        for (var i = 0; i < length; i++)
          if (_adj[i].isNotEmpty) i,
      ];
      rng.shuffle(starts);
      for (final start in starts) {
        final ends = puzzleEnds(start, range);
        if (ends.isNotEmpty) {
          return (start, ends[rng.usize(ends.length)]);
        }
      }
      return null;
    }

    final maxHops = range.max;
    for (var attempt = 0; attempt < _puzzleAttempts; attempt++) {
      final start = rng.usize(length);
      if (_adj[start].isEmpty) continue;
      final end = _randomEnd(rng, start, maxHops, _endAttempts);
      if (end != null) {
        return (start, end);
      }
    }

    final starts = <int>[
      for (var i = 0; i < length; i++)
        if (_adj[i].isNotEmpty) i,
    ];
    rng.shuffle(starts);
    for (final start in starts) {
      final end = _randomEnd(rng, start, maxHops, 0x7fffffff);
      if (end != null) {
        return (start, end);
      }
    }
    return null;
  }

  int? _randomEnd(Fastrand rng, int start, int? maxHops, int attempts) {
    final startCode = code(start);
    final reachable = _within(start, maxHops);
    final ends = <int>[
      for (final end in reachable)
        if (lettersApart(startCode, code(end)) == 3) end,
    ];
    rng.shuffle(ends);
    final limit = math.min(attempts, ends.length);
    for (var i = 0; i < limit; i++) {
      final end = ends[i];
      final res = shortest(start, end);
      if (res != null) {
        final path = res.$2;
        if ((maxHops == null || path.length - 1 <= maxHops) &&
            _crossesALoop(path)) {
          return end;
        }
      }
    }
    return null;
  }

  /// Deterministic daily puzzle for `utcDay` (days since 1970-01-01), identical to `jotto-cli`.
  (int, int)? dailyPuzzle(int utcDay, HopRange range) {
    final rng = Fastrand.forDaily(utcDay);
    return randomPuzzle(rng, range);
  }

  List<int> _within(int start, int? maxHops) {
    final depth = List<int>.filled(length, -1);
    depth[start] = 0;
    final queue = ListQueue<int>()..add(start);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (maxHops != null && depth[node] >= maxHops) {
        continue;
      }
      for (final h in _adj[node]) {
        if (depth[h.to] == -1) {
          depth[h.to] = depth[node] + 1;
          queue.addLast(h.to);
        }
      }
    }
    return [
      for (var i = 0; i < length; i++)
        if (depth[i] != -1) i,
    ];
  }

  /// Parses `flights.tsv` for a given `maxConnections` limit (0, 1, or 2).
  static Network parse(String text, int maxConnections) {
    if (maxConnections < 0 || maxConnections > maxConnectionsLimit) {
      throw ArgumentError('hops have at most $maxConnectionsLimit connections');
    }

    final codes = <String>[];
    final coords = <LatLon>[];
    final places = <(String, String)>[];
    final routes = <_RawRoute>[];
    final puzzleCounts = <(int, int)>[];

    final lines = text.split('\n');
    for (var idx = 0; idx < lines.length; idx++) {
      final lineNum = idx + 1;
      final line = lines[idx].trimRight();
      if (line.isEmpty || line.startsWith('#')) continue;
      final fields = line.split('\t');
      Never bad() => throw FormatException("line $lineNum: can't read '$line'");

      switch (fields[0]) {
        case 'A':
          if (fields.length < 4 || fields.length > 6) bad();
          final code = fields[1];
          if (code.length != 3) bad();
          final lat = double.tryParse(fields[2]) ?? bad();
          final lon = double.tryParse(fields[3]) ?? bad();
          final city = fields.length > 4 ? fields[4].trim() : '';
          final country = fields.length > 5 ? fields[5].trim() : '';
          codes.add(code);
          coords.add(LatLon(lat, lon));
          places.add((city, country));
        case 'H':
          final itCount = fields.length - 3;
          if (itCount < maxConnectionsLimit + 1 ||
              itCount > maxConnectionsLimit + 2) {
            bad();
          }
          final a = fields[1];
          final b = fields[2];
          final itineraries = fields.sublist(3);
          final best = itineraries[maxConnections];
          if (best != 'x') {
            final others = <String>[];
            for (var i = 0; i < maxConnections; i++) {
              final it = itineraries[i];
              if (it != 'x' && it != best) others.add(it);
            }
            if (itineraries.length > maxConnectionsLimit + 1) {
              for (final it
                  in itineraries[maxConnectionsLimit + 1].split(';')) {
                if (it != 'x' && it != best) others.add(it);
              }
            }
            routes.add(
              _RawRoute(
                  a: a, b: b, best: best, others: others, lineNum: lineNum),
            );
          }
        case 'P':
          if (fields.length != 4) bad();
          final limit = int.tryParse(fields[1]) ?? bad();
          if (limit == maxConnections) {
            final hops = int.tryParse(fields[2]) ?? bad();
            final count = int.tryParse(fields[3]) ?? bad();
            puzzleCounts.add((hops, count));
          }
        default:
          bad();
      }
    }

    final adjMutable = List<List<Hop>>.generate(codes.length, (_) => <Hop>[]);

    int? indexOfCode(String target) {
      var low = 0;
      var high = codes.length - 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        final c = codes[mid].compareTo(target);
        if (c < 0) {
          low = mid + 1;
        } else if (c > 0) {
          high = mid - 1;
        } else {
          return mid;
        }
      }
      return null;
    }

    for (final route in routes) {
      final x = indexOfCode(route.a);
      final y = indexOfCode(route.b);
      if (x == null || y == null) {
        throw FormatException(
          'line ${route.lineNum}: hop through an unlisted airport',
        );
      }

      List<int> readItinerary(String it) {
        if (it == '-') return const [];
        return [
          for (final c in it.split(','))
            indexOfCode(c) ??
                (throw FormatException(
                  'line ${route.lineNum}: hop through an unlisted airport',
                )),
        ];
      }

      double lengthOf(List<int> via) {
        if (via.isEmpty) {
          return greatCircleNm(coords[x], coords[y]);
        }
        var total = greatCircleNm(coords[x], coords[via.first]);
        for (var i = 0; i < via.length - 1; i++) {
          total += greatCircleNm(coords[via[i]], coords[via[i + 1]]);
        }
        total += greatCircleNm(coords[via.last], coords[y]);
        return total;
      }

      final via = readItinerary(route.best);
      final distance = lengthOf(via);

      final spare = <Ticket>[];
      for (final it in route.others) {
        final spVia = readItinerary(it);
        if (spVia.length <= maxConnections) {
          spare.add(Ticket(via: spVia, distance: lengthOf(spVia)));
        }
      }
      spare.sort((p, q) => p.distance.compareTo(q.distance));

      final spareBack = [
        for (final t in spare)
          Ticket(via: t.via.reversed.toList(), distance: t.distance),
      ];

      adjMutable[y].add(
        Hop(
          to: x,
          via: via.reversed.toList(),
          distance: distance,
          spare: spareBack,
        ),
      );
      adjMutable[x].add(
        Hop(
          to: y,
          via: via,
          distance: distance,
          spare: spare,
        ),
      );
    }

    final adj = <List<Hop>>[];
    for (final list in adjMutable) {
      list.sort((a, b) => a.to.compareTo(b.to));
      final deduped = <Hop>[];
      for (final h in list) {
        if (deduped.isEmpty || deduped.last.to != h.to) {
          deduped.add(h);
        }
      }
      adj.add(deduped);
    }

    final bridges = _findBridges(codes.length, adj);
    return Network._(
      maxConnections: maxConnections,
      codes: codes,
      coords: coords,
      places: places,
      adj: adj,
      bridges: bridges,
      puzzleCounts: puzzleCounts,
    );
  }

  static Set<int> _findBridges(int n, List<List<Hop>> adj) {
    final disc = List<int>.filled(n, -1);
    final low = List<int>.filled(n, 0);
    final out = <int>{};
    var timer = 0;

    final stackNode = List<int>.filled(n + 1, 0);
    final stackParent = List<int>.filled(n + 1, 0);
    final stackPos = List<int>.filled(n + 1, 0);

    for (var root = 0; root < n; root++) {
      if (disc[root] != -1) continue;
      disc[root] = timer;
      low[root] = timer;
      timer++;

      var top = 0;
      stackNode[0] = root;
      stackParent[0] = -1;
      stackPos[0] = 0;

      while (top >= 0) {
        final node = stackNode[top];
        final parent = stackParent[top];
        final pos = stackPos[top];
        final neighbors = adj[node];

        if (pos < neighbors.length) {
          stackPos[top] = pos + 1;
          final next = neighbors[pos].to;
          if (next == parent) continue;
          if (disc[next] == -1) {
            disc[next] = timer;
            low[next] = timer;
            timer++;
            top++;
            stackNode[top] = next;
            stackParent[top] = node;
            stackPos[top] = 0;
          } else {
            low[node] = math.min(low[node], disc[next]);
          }
        } else {
          top--;
          if (parent != -1) {
            low[parent] = math.min(low[parent], low[node]);
            if (low[node] > disc[parent]) {
              out.add(_edgeKey(node, parent));
            }
          }
        }
      }
    }
    return out;
  }
}
