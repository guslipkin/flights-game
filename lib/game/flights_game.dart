import 'dart:math' as math;

import '../data/fastrand.dart';
import '../data/network.dart';

const int minHopsLimit = 3;
const int maxHopsLimit = 20;
const int _onceDealAttempts = 200;
const double _tieNm = 1e-6;
const int saveVersion = 1;
const int placeWidth = 20;

const String youLeftRemark = '↑ you left here';
const String wentHereRemark = '↑ went here';
const String nextHopRemark = '↑ next hop';

/// Formats an integer with US thousand separators (`"1,234"`).
String grouped(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(s[i]);
  }
  return buf.toString();
}

String pluralS(int n) => n == 1 ? '' : 's';

/// Reads a 3-letter airport code typed in any case ("lax" -> "LAX").
String? parseCode(String text) {
  final clean = text.trim().toUpperCase();
  if (clean.length != 3) return null;
  for (var i = 0; i < 3; i++) {
    final c = clean.codeUnitAt(i);
    if (c < 0x41 || c > 0x5A) return null;
  }
  return clean;
}

/// Shortens a place string `"City, CC"` to `width` characters, truncating only the city
/// with `"…"` while keeping `", CC"` intact (`fit_place` in `jotto-cli`).
String fitPlace(String text, int width) {
  if (text.length <= width) return text;
  final lastComma = text.lastIndexOf(', ');
  String city;
  String country;
  if (lastComma >= 0 && text.length - (lastComma + 2) <= 3) {
    city = text.substring(0, lastComma);
    country = text.substring(lastComma);
  } else {
    city = text;
    country = '';
  }
  final room = math.max(1, width - (country.length + 1));
  final cut = city.substring(0, math.min(city.length, room)).trimRight();
  return '$cut…$country';
}

String shortPlace(String text) => fitPlace(text, placeWidth);

/// How long a puzzle may be and how much the player is shown.
enum Difficulty {
  easy('Easy', 'up to 4 hops; map, distances and connections'),
  medium('Medium', 'up to 6 hops; map and connections'),
  hard('Hard', 'up to 8 hops; connections only'),
  pilot('Pilot', 'any length; codes only'),
  custom('Custom', 'your own settings');

  const Difficulty(this.label, this.description);

  final String label;
  final String description;

  static const List<Difficulty> standard = [
    Difficulty.easy,
    Difficulty.medium,
    Difficulty.hard,
    Difficulty.pilot,
  ];

  static const Difficulty dailyDifficulty = Difficulty.medium;

  Difficulty next() {
    const all = Difficulty.values;
    return all[(index + 1) % all.length];
  }

  Rules rules([Rules customRules = const Rules()]) {
    return this == Difficulty.custom ? customRules : Rules.standard(this);
  }

  int puzzleCount(Network Function(int) networkProvider) {
    return rules().puzzleCount(networkProvider);
  }

  static Difficulty? fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'easy':
      case 'e':
        return Difficulty.easy;
      case 'medium':
      case 'med':
      case 'm':
        return Difficulty.medium;
      case 'hard':
      case 'h':
        return Difficulty.hard;
      case 'pilot':
      case 'p':
        return Difficulty.pilot;
      case 'custom':
      case 'c':
        return Difficulty.custom;
      default:
        return null;
    }
  }
}

/// What a game shows while it's played.
class ViewConfig {
  const ViewConfig({
    this.map = true,
    this.distances = false,
    this.connections = true,
    this.amountOver = true,
  });

  final bool map;
  final bool distances;
  final bool connections;
  final bool amountOver;

  factory ViewConfig.of(Difficulty level) {
    return ViewConfig(
      map: level == Difficulty.easy ||
          level == Difficulty.medium ||
          level == Difficulty.custom,
      distances: level == Difficulty.easy,
      connections: level != Difficulty.pilot,
      amountOver: level == Difficulty.easy ||
          level == Difficulty.medium ||
          level == Difficulty.custom,
    );
  }

  Difficulty? level() {
    for (final d in Difficulty.standard) {
      if (ViewConfig.of(d) == this) return d;
    }
    return null;
  }

  String label() => level()?.label ?? 'Mixed';

  String parts() {
    final list = <String>[
      if (map) 'map',
      if (distances) 'distances',
      if (connections) 'connections',
      if (amountOver) 'how far over',
    ];
    if (list.isEmpty) return 'codes only';
    if (list.length == 1) return list.first;
    return '${list.sublist(0, list.length - 1).join(', ')} and ${list.last}';
  }

  ViewConfig copyWith({
    bool? map,
    bool? distances,
    bool? connections,
    bool? amountOver,
  }) {
    return ViewConfig(
      map: map ?? this.map,
      distances: distances ?? this.distances,
      connections: connections ?? this.connections,
      amountOver: amountOver ?? this.amountOver,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewConfig &&
      other.map == map &&
      other.distances == distances &&
      other.connections == connections &&
      other.amountOver == amountOver;

  @override
  int get hashCode => Object.hash(map, distances, connections, amountOver);
}

const Object _unset = Object();

/// What a game deals and shows: a standard level's fixed rules, or a custom game's.
class Rules {
  const Rules({
    this.view = const ViewConfig(),
    this.minHops = minHopsLimit,
    this.maxHops = 6,
    this.maxConnections = standardConnections,
    this.showPlaces = true,
    this.fixedRoute = false,
    this.start,
    this.end,
    this.reuseConnections = true,
  });

  final ViewConfig view;
  final int minHops;
  final int? maxHops;
  final int maxConnections;
  final bool showPlaces;
  final bool fixedRoute;
  final String? start;
  final String? end;
  final bool reuseConnections;

  factory Rules.standard(Difficulty level) {
    final int? maxH;
    switch (level) {
      case Difficulty.easy:
        maxH = 4;
      case Difficulty.medium:
        maxH = 6;
      case Difficulty.hard:
        maxH = 8;
      case Difficulty.pilot:
      case Difficulty.custom:
        maxH = null;
    }
    return Rules(
      view: ViewConfig.of(level),
      minHops: minHopsLimit,
      maxHops: maxH,
      maxConnections: standardConnections,
      showPlaces: true,
      fixedRoute: false,
      start: null,
      end: null,
      reuseConnections: true,
    );
  }

  Rules copyWith({
    ViewConfig? view,
    int? minHops,
    Object? maxHops = _unset,
    int? maxConnections,
    bool? showPlaces,
    bool? fixedRoute,
    Object? start = _unset,
    Object? end = _unset,
    bool? reuseConnections,
  }) {
    return Rules(
      view: view ?? this.view,
      minHops: minHops ?? this.minHops,
      maxHops: identical(maxHops, _unset) ? this.maxHops : maxHops as int?,
      maxConnections: maxConnections ?? this.maxConnections,
      showPlaces: showPlaces ?? this.showPlaces,
      fixedRoute: fixedRoute ?? this.fixedRoute,
      start: identical(start, _unset) ? this.start : start as String?,
      end: identical(end, _unset) ? this.end : end as String?,
      reuseConnections: reuseConnections ?? this.reuseConnections,
    );
  }

  HopRange hopRange() {
    return fixedRoute ? const HopRange() : HopRange(min: minHops, max: maxHops);
  }

  int connections() => fixedRoute ? standardConnections : maxConnections;

  bool oncePerAirport() => !reuseConnections && connections() > 0;

  bool showsMap() => view.map;
  bool showsDistances() => view.distances;
  bool showsAmountOver() => view.amountOver;
  bool showsConnections() => view.connections;

  bool countIsExact() {
    return !oncePerAirport() || (fixedRoute && start != null && end != null);
  }

  bool _playable(Network net, int startIdx, int endIdx) {
    if (!oncePerAirport()) {
      return net.isValidPuzzle(startIdx, endIdx);
    }
    return lettersApart(net.code(startIdx), net.code(endIdx)) == 3 &&
        net.routesOnce(startIdx, endIdx, 2).length == 2;
  }

  bool _deals(Network net, int startIdx, int endIdx) {
    if (lettersApart(net.code(startIdx), net.code(endIdx)) != 3) return false;
    final routes = net.routesOnce(startIdx, endIdx, 2);
    return routes.length == 2 &&
        hopRange().contains(routes[0].stops.length - 1);
  }

  (int?, int?, String?) _fixed(Network net) {
    if (!fixedRoute) return (null, null, null);

    (int?, String?) find(String? code) {
      if (code == null) return (null, null);
      final idx = net.indexOf(code);
      if (idx == null || net.hops(idx).isEmpty) {
        final c = connections();
        return (
          null,
          '$code has no hops with $c connection${pluralS(c)}',
        );
      }
      return (idx, null);
    }

    final (sIdx, sErr) = find(start);
    if (sErr != null) return (null, null, sErr);
    final (eIdx, eErr) = find(end);
    if (eErr != null) return (null, null, eErr);

    if (sIdx != null && eIdx != null) {
      final ca = net.code(sIdx);
      final cb = net.code(eIdx);
      if (lettersApart(ca, cb) != 3) {
        return (null, null, '$ca and $cb must differ in every letter');
      }
      if (!_playable(net, sIdx, eIdx)) {
        final routes = oncePerAirport()
            ? net.routesOnce(sIdx, eIdx, 1).length
            : (net.shortest(sIdx, eIdx) != null ? 1 : 0);
        final once = oncePerAirport() ? ' using each airport once' : '';
        final msg = routes == 0
            ? "there's no way from $ca to $cb$once"
            : 'only one route joins $ca and $cb$once';
        return (null, null, msg);
      }
    }
    return (sIdx, eIdx, null);
  }

  /// Returns `(puzzleCount, errorMessage)` for these rules.
  (int?, String?) check(Network Function(int) networkProvider) {
    final net = networkProvider(connections());
    final (s, e, err) = _fixed(net);
    if (err != null) return (null, err);

    final int count;
    if (s == null && e == null) {
      count = net.puzzleCount(hopRange());
    } else if (s != null && e == null) {
      count = net.puzzleEnds(s, hopRange()).length;
    } else if (s == null && e != null) {
      count = net.puzzleEnds(e, hopRange()).length;
    } else {
      count = 1;
    }

    if (count == 0) {
      return (null, 'no puzzles fit these settings');
    }
    return (count, null);
  }

  int puzzleCount(Network Function(int) networkProvider) =>
      check(networkProvider).$1 ?? 0;

  ((int, int)?, String?) deal(Network net, Fastrand rng) {
    final (s, e, fixedErr) = _fixed(net);
    if (fixedErr != null) return (null, fixedErr);

    if (oncePerAirport()) {
      final dealt = _dealOnce(net, rng, s, e);
      if (dealt != null) return (dealt, null);
      return (null, 'no puzzles fit these settings');
    }

    if (s == null && e == null) {
      final pair = net.randomPuzzle(rng, hopRange());
      return pair != null
          ? (pair, null)
          : (null, 'no puzzles fit these settings');
    } else if (s != null && e == null) {
      final ends = net.puzzleEnds(s, hopRange());
      return ends.isNotEmpty
          ? ((s, ends[rng.usize(ends.length)]), null)
          : (null, 'no puzzles fit these settings');
    } else if (s == null && e != null) {
      final starts = net.puzzleEnds(e, hopRange());
      return starts.isNotEmpty
          ? ((starts[rng.usize(starts.length)], e), null)
          : (null, 'no puzzles fit these settings');
    } else {
      return ((s!, e!), null);
    }
  }

  (int, int)? _dealOnce(Network net, Fastrand rng, int? s, int? e) {
    if (s != null && e != null) return (s, e);
    if (s == null && e == null) {
      for (var attempt = 0; attempt < _onceDealAttempts; attempt++) {
        final pair = net.randomPuzzle(rng, hopRange());
        if (pair == null) return null;
        if (_deals(net, pair.$1, pair.$2)) return pair;
      }
      return null;
    }
    final fixedAirport = s ?? e!;
    final ends = List<int>.from(net.puzzleEnds(fixedAirport, hopRange()));
    rng.shuffle(ends);
    final limit = math.min(_onceDealAttempts, ends.length);
    for (var i = 0; i < limit; i++) {
      final b = ends[i];
      final pair = start != null ? (fixedAirport, b) : (b, fixedAirport);
      if (_deals(net, pair.$1, pair.$2)) return pair;
    }
    return null;
  }

  String hopsText() {
    final range = hopRange();
    final min = math.max(minHopsLimit, range.min);
    final max = range.max;
    if (max != null && max == min) return '$max hops';
    if (max != null && min == minHopsLimit) return 'up to $max hops';
    if (max != null) return '$min to $max hops';
    if (min == minHopsLimit) return 'any number of hops';
    return 'at least $min hops';
  }

  String _viewText() {
    final lvl = view.level();
    return lvl != null ? '${lvl.label} view' : 'shows ${view.parts()}';
  }

  String summary() {
    if (fixedRoute) {
      final s = start ?? 'random';
      final e = end ?? 'random';
      final once = oncePerAirport() ? ', each airport once' : '';
      final places = showPlaces ? '' : ', no places';
      return '${_viewText()}, route $s → $e$once$places';
    }
    final c = connections();
    final once = oncePerAirport() ? ', each airport once' : '';
    final places = showPlaces ? '' : ', no places';
    return '${_viewText()}, ${hopsText()}, up to $c connection${pluralS(c)}$once$places';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'view': <String, dynamic>{
        'map': view.map,
        'distances': view.distances,
        'connections': view.connections,
        'amount_over': view.amountOver,
      },
      if (minHops != minHopsLimit) 'min_hops': minHops,
      'max_hops': maxHops,
      'max_connections': maxConnections,
      'show_places': showPlaces,
      if (fixedRoute) 'fixed_route': true,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (!reuseConnections) 'reuse_connections': false,
    };
  }

  static Rules? fromJson(Map<String, dynamic> obj) {
    final viewVal = obj['view'];
    ViewConfig? view;
    if (viewVal is String) {
      final d = Difficulty.fromName(viewVal);
      if (d != null && d != Difficulty.custom) {
        view = ViewConfig.of(d);
      }
    } else if (viewVal is Map<String, dynamic>) {
      view = ViewConfig(
        map: (viewVal['map'] as bool?) ?? true,
        distances: (viewVal['distances'] as bool?) ?? false,
        connections: (viewVal['connections'] as bool?) ?? true,
        amountOver: (viewVal['amount_over'] as bool?) ?? true,
      );
    }
    if (view == null) return null;

    final minH = (obj['min_hops'] as int?) ?? minHopsLimit;
    final maxH = obj['max_hops'] as int?;
    bool inBounds(int n) => n >= minHopsLimit && n <= maxHopsLimit;
    final hopsOk =
        inBounds(minH) && (maxH == null || (inBounds(maxH) && minH <= maxH));
    final maxConn = (obj['max_connections'] as int?) ?? standardConnections;
    if (!hopsOk || maxConn < 0 || maxConn > maxConnectionsLimit) return null;

    final rawStart = obj['start'] as String?;
    final rawEnd = obj['end'] as String?;
    final s =
        (rawStart == null || rawStart.isEmpty) ? null : parseCode(rawStart);
    final e = (rawEnd == null || rawEnd.isEmpty) ? null : parseCode(rawEnd);

    return Rules(
      view: view,
      minHops: minH,
      maxHops: maxH,
      maxConnections: maxConn,
      showPlaces: (obj['show_places'] as bool?) ?? true,
      fixedRoute: (obj['fixed_route'] as bool?) ?? false,
      start: s,
      end: e,
      reuseConnections: (obj['reuse_connections'] as bool?) ?? true,
    );
  }
}

/// Distance units (`nm`, `mi`, `km`).
enum Units {
  nm('nm', 'Nautical miles'),
  mi('mi', 'Statute miles'),
  km('km', 'Kilometres');

  const Units(this.label, this.fullName);

  final String label;
  final String fullName;

  Units next() {
    const all = Units.values;
    return all[(index + 1) % all.length];
  }

  double convert(double nauticalMiles) {
    switch (this) {
      case Units.nm:
        return nauticalMiles;
      case Units.mi:
        return nauticalMiles * 1.150779;
      case Units.km:
        return nauticalMiles * 1.852;
    }
  }

  String format(double nauticalMiles) {
    final rounded = convert(nauticalMiles).round();
    return '${grouped(rounded)} $label';
  }

  static Units? fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'nm':
      case 'nmi':
        return Units.nm;
      case 'mi':
      case 'miles':
        return Units.mi;
      case 'km':
      case 'kilometers':
      case 'kilometres':
        return Units.km;
      default:
        return null;
    }
  }
}

enum GameStatus { playing, won, givenUp }

sealed class FlyOutcome {
  const FlyOutcome();
}

class FlewOutcome extends FlyOutcome {
  const FlewOutcome(this.distance);
  final double distance;
}

class LongerOutcome extends FlyOutcome {
  const LongerOutcome(this.over);
  final double over;
}

class WonOutcome extends FlyOutcome {
  const WonOutcome();
}

/// An airport the player can fly to next.
class FlightOption {
  const FlightOption({
    required this.airport,
    required this.code,
    required this.distance,
    required this.via,
    required this.connections,
    required this.changed,
  });

  final int airport;
  final String code;
  final double distance;
  final List<String> via;
  final List<int> connections;
  final int changed;
}

/// State machine for a `Flights` game session, ported from `jotto-cli/src/flights/game.rs`.
class FlightsGame {
  FlightsGame._({
    required this.net,
    required this.origin,
    required this.destination,
    required List<int> route,
    required List<Ticket> legs,
    required this.bestDistance,
    required this.bestRoute,
    required this.bestLegs,
    required this.difficulty,
    required this.rules,
    required this.custom,
    required this.units,
    required this.curves,
    required this.dailyDate,
    required this.longerArrivals,
    required this.status,
  })  : _route = route,
        _legs = legs;

  Network net;
  final int origin;
  final int destination;
  final List<int> _route;
  final List<Ticket> _legs;
  final double bestDistance;
  final List<int> bestRoute;
  final List<Ticket> bestLegs;
  Difficulty difficulty;
  Rules rules;
  Rules custom;
  Units units;
  bool curves;
  String? dailyDate;
  int longerArrivals;
  GameStatus status;

  List<int> get route => List<int>.unmodifiable(_route);
  List<Ticket> get legs => List<Ticket>.unmodifiable(_legs);

  String get startCode => net.code(origin);
  String get endCode => net.code(destination);
  int get current => _route.last;
  String get currentCode => net.code(current);
  int get hops => _route.length - 1;

  double totalDistance() {
    var sum = 0.0;
    for (final leg in _legs) {
      sum += leg.distance;
    }
    return sum;
  }

  bool distancesVisible() =>
      rules.showsDistances() || status != GameStatus.playing;

  bool atDestination() => current == destination;

  int divergence() {
    final len = math.min(_route.length, bestRoute.length);
    var count = 0;
    while (count < len && _route[count] == bestRoute[count]) {
      count++;
    }
    return count;
  }

  String divergenceText() {
    final split = divergence();
    if (_route.length == 1) {
      return "You hadn't left the start.";
    } else if (split == _route.length) {
      return 'Your route so far follows it.';
    } else {
      final afterCode = net.code(_route[split - 1]);
      final flewCode = net.code(_route[split]);
      final bestCode = net.code(bestRoute[split]);
      return 'You left it after $afterCode: you flew to $flewCode, the shortest goes to $bestCode.';
    }
  }

  bool _used(int airport) {
    return _route.contains(airport) ||
        (rules.oncePerAirport() &&
            _legs.any((leg) => leg.via.contains(airport)));
  }

  Ticket? _ticketFor(Hop hop) {
    return rules.oncePerAirport() ? hop.ticketAvoiding(_used) : hop.ticket();
  }

  List<FlightOption> options() {
    if (status != GameStatus.playing || atDestination()) {
      return const [];
    }
    final here = net.code(current);
    final rawOptions = <FlightOption>[];
    for (final h in net.hops(current)) {
      if (_used(h.to)) continue;
      final ticket = _ticketFor(h);
      if (ticket == null) continue;
      final code = net.code(h.to);
      var changed = 0;
      for (var i = 0; i < 3; i++) {
        if (here.codeUnitAt(i) != code.codeUnitAt(i)) {
          changed = i;
          break;
        }
      }
      rawOptions.add(
        FlightOption(
          airport: h.to,
          code: code,
          distance: ticket.distance,
          via: [for (final idx in ticket.via) net.code(idx)],
          connections: ticket.via,
          changed: changed,
        ),
      );
    }
    rawOptions.sort((a, b) {
      final aDest = a.airport == destination ? 0 : 1;
      final bDest = b.airport == destination ? 0 : 1;
      return aDest.compareTo(bDest);
    });
    return rawOptions;
  }

  /// Flies to `rawCode`. Returns `(FlyOutcome?, errorMessage)`.
  (FlyOutcome?, String?) fly(String rawCode) {
    if (status != GameStatus.playing) {
      return (null, 'The game is over. Start a New Game to play again.');
    }
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return (null, 'Choose an airport code to fly to.');
    }
    if (parseCode(code) == null) {
      return (null, "'$code' isn't an airport code: codes are 3 letters.");
    }
    if (atDestination()) {
      return (
        null,
        "You're at the destination, but not by the shortest route. Go back to try another.",
      );
    }
    final from = net.code(current);
    final to = net.indexOf(code);
    if (to == null) {
      return (
        null,
        "$code isn't in the game: it has no flights to a code one letter away.",
      );
    }
    if (_route.contains(to)) {
      return (
        null,
        '$code is already on your route. Go back to it instead of flying there.',
      );
    }
    if (_used(to)) {
      return (
        null,
        "You've already connected through $code, and this game uses each airport once.",
      );
    }
    if (lettersApart(from, code) != 1) {
      return (null, "$code isn't one letter away from $from.");
    }
    final hop = net.hop(current, to);
    if (hop == null) {
      final mc = net.maxConnections;
      final msg = mc == 0
          ? "There's no direct flight from $from to $code."
          : mc == 1
              ? "There's no ticket from $from to $code, direct or with one connection."
              : "There's no ticket from $from to $code with $mc connections or fewer.";
      return (null, msg);
    }
    final ticket = _ticketFor(hop);
    if (ticket == null) {
      return (
        null,
        "Every ticket from $from to $code connects through an airport you've already used.",
      );
    }

    _route.add(to);
    _legs.add(ticket);

    if (to != destination) {
      return (FlewOutcome(ticket.distance), null);
    }
    final over = totalDistance() - bestDistance;
    if (over <= _tieNm) {
      status = GameStatus.won;
      return (const WonOutcome(), null);
    } else {
      longerArrivals++;
      return (LongerOutcome(over), null);
    }
  }

  /// Goes back to the previous airport, returning the airport index left, or `null` at start.
  int? back() {
    if (status != GameStatus.playing || _route.length < 2) {
      return null;
    }
    _legs.removeLast();
    return _route.removeLast();
  }

  void giveUp() {
    if (status == GameStatus.playing) {
      status = GameStatus.givenUp;
    }
  }

  String routeText(List<int> airports) =>
      [for (final i in airports) net.code(i)].join(' → ');

  String shareSummary() {
    final h = hops;
    final tries = longerArrivals == 0
        ? 'first try'
        : longerArrivals == 1
            ? 'after 1 longer route'
            : 'after $longerArrivals longer routes';
    final daily = dailyDate != null ? ' (daily $dailyDate)' : '';
    return 'Flights $startCode → $endCode$daily: shortest route in $h hop${pluralS(h)}, ${units.format(totalDistance())}, $tries';
  }

  String shareCardText() {
    if (status == GameStatus.won) {
      final chain = <String>[
        for (var i = 0; i < _route.length; i++)
          if (i == 0) '🛫' else if (i == _route.length - 1) '🛬' else '✈️',
      ].join('→');
      return '${shareSummary()}\n$chain';
    } else {
      final daily = dailyDate != null ? ' (daily $dailyDate)' : '';
      final bestHops = bestRoute.length - 1;
      return 'Flights $startCode → $endCode$daily: shortest route is $bestHops hop${pluralS(bestHops)} (${units.format(bestDistance)})';
    }
  }

  Map<String, dynamic> toSavedJson({
    bool hapticsEnabled = true,
    bool soundEnabled = true,
  }) {
    return <String, dynamic>{
      'version': saveVersion,
      'units': units.label,
      'curves': curves,
      'haptics': hapticsEnabled,
      'sound': soundEnabled,
      'custom': custom.toJson(),
      if (status == GameStatus.playing)
        'game': <String, dynamic>{
          'difficulty': difficulty.label.toLowerCase(),
          if (difficulty == Difficulty.custom) 'rules': rules.toJson(),
          'start': startCode,
          'end': endCode,
          if (dailyDate != null) 'daily_date': dailyDate,
          'route': [for (final i in _route.sublist(1)) net.code(i)],
          'longer_arrivals': longerArrivals,
        },
    };
  }

  static FlightsGame? withPuzzle({
    required Network net,
    required int start,
    required int end,
    required Difficulty difficulty,
    Rules custom = const Rules(),
    Units units = Units.nm,
    bool curves = true,
    String? dailyDate,
  }) {
    final rules = difficulty.rules(custom);
    final OnceRoute best;
    if (rules.oncePerAirport()) {
      final found = net.routesOnce(start, end, 1);
      if (found.isEmpty) return null;
      best = found.first;
    } else {
      final res = net.shortest(start, end);
      if (res == null) return null;
      final stops = res.$2;
      final legs = <Ticket>[];
      for (var i = 0; i < stops.length - 1; i++) {
        final h = net.hop(stops[i], stops[i + 1]);
        if (h == null) return null;
        legs.add(h.ticket());
      }
      best = OnceRoute(distance: res.$1, stops: stops, legs: legs);
    }

    return FlightsGame._(
      net: net,
      origin: start,
      destination: end,
      route: <int>[start],
      legs: <Ticket>[],
      bestDistance: best.distance,
      bestRoute: best.stops,
      bestLegs: best.legs,
      difficulty: difficulty,
      rules: rules,
      custom: custom,
      units: units,
      curves: curves,
      dailyDate: dailyDate,
      longerArrivals: 0,
      status: GameStatus.playing,
    );
  }

  static (FlightsGame?, String?) random({
    required Difficulty difficulty,
    required Network Function(int) networkProvider,
    Rules custom = const Rules(),
    Units units = Units.nm,
    bool curves = true,
  }) {
    final rules = difficulty.rules(custom);
    final net = networkProvider(rules.connections());
    final (pair, err) = rules.deal(net, Fastrand());
    if (pair == null) {
      final reason = err != null && err.isNotEmpty
          ? '${err[0].toUpperCase()}${err.substring(1)}'
          : 'No puzzles fit these settings';
      return (
        null,
        "Can't start a custom game: $reason. Change it in the settings.",
      );
    }
    final game = withPuzzle(
      net: net,
      start: pair.$1,
      end: pair.$2,
      difficulty: difficulty,
      custom: custom,
      units: units,
      curves: curves,
    );
    return game != null ? (game, null) : (null, 'Puzzles are connected');
  }

  static FlightsGame dailyIn({
    required int utcDay,
    required Network Function(int) networkProvider,
    Rules custom = const Rules(),
    Units units = Units.nm,
    bool curves = true,
  }) {
    final rules = Difficulty.dailyDifficulty.rules(custom);
    final net = networkProvider(rules.connections());
    final pair = net.dailyPuzzle(utcDay, rules.hopRange());
    if (pair == null) {
      throw StateError('the daily level has puzzles');
    }
    final game = withPuzzle(
      net: net,
      start: pair.$1,
      end: pair.$2,
      difficulty: Difficulty.dailyDifficulty,
      custom: custom,
      units: units,
      curves: curves,
      dailyDate: Fastrand.formatUtcDate(utcDay),
    );
    if (game == null) {
      throw StateError('puzzles are connected');
    }
    return game;
  }

  static FlightsGame newDaily({
    required Network Function(int) networkProvider,
    Rules custom = const Rules(),
    Units units = Units.nm,
    bool curves = true,
  }) {
    return dailyIn(
      utcDay: Fastrand.currentUtcDays(),
      networkProvider: networkProvider,
      custom: custom,
      units: units,
      curves: curves,
    );
  }

  static FlightsGame? fromSavedJson(
    Map<String, dynamic> saved,
    Network Function(int) networkProvider,
  ) {
    final play = saved['game'];
    if (play is! Map<String, dynamic>) return null;
    final difficulty =
        Difficulty.fromName((play['difficulty'] as String?) ?? '');
    if (difficulty == null) return null;

    final units =
        Units.fromName((saved['units'] as String?) ?? 'nm') ?? Units.nm;
    final curves = (saved['curves'] as bool?) ?? true;
    final customMap = saved['custom'];
    final custom = customMap is Map<String, dynamic>
        ? (Rules.fromJson(customMap) ?? const Rules())
        : const Rules();

    Rules gameRules = custom;
    if (difficulty == Difficulty.custom &&
        play['rules'] is Map<String, dynamic>) {
      final parsed = Rules.fromJson(play['rules'] as Map<String, dynamic>);
      if (parsed == null) return null;
      gameRules = parsed;
    }

    final net = networkProvider(difficulty.rules(gameRules).connections());
    final startCode = (play['start'] as String?) ?? '';
    final endCode = (play['end'] as String?) ?? '';
    final startIdx = net.indexOf(startCode);
    final endIdx = net.indexOf(endCode);
    if (startIdx == null || endIdx == null) return null;
    final dailyDate = play['daily_date'] as String?;

    final game = withPuzzle(
      net: net,
      start: startIdx,
      end: endIdx,
      difficulty: difficulty,
      custom: gameRules,
      units: units,
      curves: curves,
      dailyDate: dailyDate,
    );
    if (game == null) return null;

    final routeList = play['route'];
    if (routeList is List) {
      for (final item in routeList) {
        if (item is! String) return null;
        final (_, err) = game.fly(item);
        if (err != null) return null;
      }
    }
    if (game.status != GameStatus.playing) return null;
    game.longerArrivals = (play['longer_arrivals'] as int?) ?? 0;
    game.custom = custom;
    return game;
  }
}
