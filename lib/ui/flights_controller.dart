import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/coastlines.dart';
import '../data/flights_repository.dart';
import '../data/network.dart';
import '../game/flights_game.dart';
import '../util/platform_bridge.dart';
import 'theme/flight_deck_theme.dart';

class SelectedHopInfo {
  const SelectedHopInfo({
    required this.from,
    required this.ticket,
    required this.to,
    required this.isShortestRoute,
    required this.hopNumber,
  });

  final int from;
  final Ticket ticket;
  final int to;
  final bool isShortestRoute;
  final int hopNumber;
}

class FlightsController extends ChangeNotifier {
  FlightsController({
    required this.repository,
    required FlightsGame initialGame,
    required String initialMessage,
    required Color initialMessageColor,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.themeChoice = ThemeChoice.system,
    this.darkStyle = DarkStyle.navy,
    this.oneTapToFly = false,
  })  : _game = initialGame,
        statusMessage = initialMessage,
        statusColor = initialMessageColor {
    _resetSelection();
  }

  final FlightsRepository repository;
  FlightsGame _game;

  int? selectedOptionIndex = 0;
  int? routeStep;
  MapBounds? userMapBounds;
  MapBounds lastFittedBounds = const MapBounds(
    lonMin: -180.0,
    lonMax: 180.0,
    latMin: -70.0,
    latMax: 70.0,
  );
  bool mapFullScreen = false;

  /// Set once a physical key is pressed, so help can list the keyboard
  /// shortcuts on phones and tablets that have a keyboard attached.
  bool keyboardSeen = false;
  bool routeExpanded = false;
  bool hapticsEnabled;
  bool soundEnabled;
  ThemeChoice themeChoice;
  DarkStyle darkStyle;

  /// Touch only: fly on the first tap of an option instead of previewing it
  /// first. Mouse clicks always fly on the first click, as in jotto-cli.
  bool oneTapToFly;
  String statusMessage;
  Color statusColor;

  // The route panel owns its scroll position, so Page Up/Down reach it as
  // events (pages to scroll, negative is up) rather than as controller state.
  final StreamController<int> _routePageRequests =
      StreamController<int>.broadcast();
  Stream<int> get routePageRequests => _routePageRequests.stream;

  @override
  void dispose() {
    _routePageRequests.close();
    super.dispose();
  }

  FlightsGame get game => _game;
  Network get currentNetwork => _game.net;
  CoastlineData get coastlines => repository.coastlines;
  Network Function(int) get networkProvider => repository.network;

  List<FlightOption> get options => _game.options();

  int get stepCount {
    final best = _game.status == GameStatus.givenUp ? _game.bestLegs.length : 0;
    return _game.legs.length + best;
  }

  SelectedHopInfo? get selectedHop {
    final step = routeStep;
    if (step == null) return null;
    final yours = _game.legs.length;
    if (step < yours) {
      if (step + 1 >= _game.route.length) return null;
      return SelectedHopInfo(
        from: _game.route[step],
        ticket: _game.legs[step],
        to: _game.route[step + 1],
        isShortestRoute: false,
        hopNumber: step + 1,
      );
    } else {
      final idx = step - yours;
      if (idx < 0 ||
          idx >= _game.bestLegs.length ||
          idx + 1 >= _game.bestRoute.length) {
        return null;
      }
      return SelectedHopInfo(
        from: _game.bestRoute[idx],
        ticket: _game.bestLegs[idx],
        to: _game.bestRoute[idx + 1],
        isShortestRoute: true,
        hopNumber: idx + 1,
      );
    }
  }

  static Future<FlightsController> create(FlightsRepository repo) async {
    var savedUnits = Units.nm;
    var savedCurves = true;
    var savedCustom = const Rules();
    var haptics = true;
    var sound = true;
    var theme = ThemeChoice.system;
    var dark = DarkStyle.navy;
    var oneTap = false;

    final rawJson = await PlatformBridge.readSaveJson();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final flightsObj = decoded['flights'] is Map<String, dynamic>
              ? decoded['flights'] as Map<String, dynamic>
              : decoded;
          savedUnits =
              Units.fromName((flightsObj['units'] as String?) ?? 'nm') ??
                  Units.nm;
          savedCurves = (flightsObj['curves'] as bool?) ?? true;
          haptics = (flightsObj['haptics'] as bool?) ?? true;
          sound = (flightsObj['sound'] as bool?) ?? true;
          theme = ThemeChoice.fromName(flightsObj['theme'] as String?);
          dark = DarkStyle.fromName(flightsObj['dark_style'] as String?);
          oneTap = (flightsObj['one_tap'] as bool?) ?? false;
          if (flightsObj['custom'] is Map<String, dynamic>) {
            savedCustom =
                Rules.fromJson(flightsObj['custom'] as Map<String, dynamic>) ??
                    const Rules();
          }

          final restored = FlightsGame.fromSavedJson(flightsObj, repo.network);
          if (restored != null) {
            restored.units = savedUnits;
            restored.curves = savedCurves;
            restored.custom = savedCustom;
            final notice = restored.dailyDate != null
                ? 'Resumed saved Daily Challenge (${restored.dailyDate} UTC).'
                : 'Resumed saved game (${restored.startCode} → ${restored.endCode}).';
            return FlightsController(
              repository: repo,
              initialGame: restored,
              initialMessage: notice,
              initialMessageColor: FlightDeckColors.accentSkyBlue,
              hapticsEnabled: haptics,
              soundEnabled: sound,
              themeChoice: theme,
              darkStyle: dark,
              oneTapToFly: oneTap,
            );
          }
        }
      } catch (_) {}
    }

    final (fresh, _) = FlightsGame.random(
      difficulty: Difficulty.medium,
      networkProvider: repo.network,
      custom: savedCustom,
      units: savedUnits,
      curves: savedCurves,
    );
    final game = fresh ??
        FlightsGame.random(
          difficulty: Difficulty.medium,
          networkProvider: repo.network,
          units: savedUnits,
          curves: savedCurves,
        ).$1!;

    return FlightsController(
      repository: repo,
      initialGame: game,
      initialMessage: _welcomeMessage(game),
      initialMessageColor: FlightDeckColors.textSecondary,
      hapticsEnabled: haptics,
      soundEnabled: sound,
      themeChoice: theme,
      darkStyle: dark,
      oneTapToFly: oneTap,
    );
  }

  static String _welcomeMessage(FlightsGame g) {
    return 'Fly from ${g.startCode} to ${g.endCode} by the shortest route, changing one letter per hop.';
  }

  void _resetSelection() {
    routeStep = null;
    final opts = _game.options();
    selectedOptionIndex = opts.isNotEmpty ? 0 : null;
  }

  Future<void> _saveCurrentState() async {
    try {
      final root = <String, dynamic>{
        'flights': {
          ..._game.toSavedJson(
            hapticsEnabled: hapticsEnabled,
            soundEnabled: soundEnabled,
          ),
          'theme': themeChoice.name,
          'dark_style': darkStyle.name,
          'one_tap': oneTapToFly,
        },
      };
      await PlatformBridge.writeSaveJson(jsonEncode(root));
    } catch (_) {}
  }

  /// Whether a tap or click from `kind` flies straight away rather than
  /// selecting first.
  bool _fliesOnFirstTap(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ||
      kind == PointerDeviceKind.trackpad ||
      oneTapToFly;

  void onOptionTapped(
    int index, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) {
    if (_game.status != GameStatus.playing) return;
    final opts = _game.options();
    if (index < 0 || index >= opts.length) return;

    if (selectedOptionIndex == index || _fliesOnFirstTap(kind)) {
      flyToCode(opts[index].code);
    } else {
      selectedOptionIndex = index;
      PlatformBridge.onPreviewSelect(hapticsEnabled: hapticsEnabled);
      notifyListeners();
    }
  }

  void flyToSelected() {
    if (_game.status != GameStatus.playing) return;
    final opts = _game.options();
    final idx = selectedOptionIndex;
    if (idx == null || idx < 0 || idx >= opts.length) return;
    flyToCode(opts[idx].code);
  }

  void onMapAirportTapped(
    int airportIdx, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) {
    if (_game.status != GameStatus.playing) return;
    final opts = _game.options();
    final matchIndex = opts.indexWhere((o) => o.airport == airportIdx);
    if (matchIndex >= 0) {
      onOptionTapped(matchIndex, kind: kind);
    }
  }

  void flyToCode(String rawCode) {
    final code = rawCode.toUpperCase();
    final (outcome, err) = _game.fly(code);
    if (err != null) {
      statusMessage = err;
      statusColor = FlightDeckColors.warningOrange;
    } else if (outcome is FlewOutcome) {
      final details = <String>[
        if (_game.rules.showsDistances()) _game.units.format(outcome.distance),
        if (_arrivalVia().isNotEmpty) _arrivalVia().trimLeft(),
      ];
      final suffix = details.isEmpty ? '' : ' (${details.join(' ')})';
      statusMessage = 'Flew to $code$suffix.';
      statusColor = FlightDeckColors.textSecondary;
      PlatformBridge.onHop(
        hapticsEnabled: hapticsEnabled,
        soundEnabled: soundEnabled,
      );
    } else if (outcome is LongerOutcome) {
      final how = _game.rules.showsAmountOver()
          ? '${_game.units.format(outcome.over)} longer than the shortest route'
          : 'not by the shortest route';
      statusMessage =
          'You reached $code, but $how.\nTap Go Back to find a shorter way.';
      statusColor = FlightDeckColors.warningOrange;
      PlatformBridge.onLongerRoute(
        hapticsEnabled: hapticsEnabled,
        soundEnabled: soundEnabled,
      );
    } else if (outcome is WonOutcome) {
      statusMessage = 'You found the shortest route!\n${_game.shareSummary()}';
      statusColor = FlightDeckColors.positiveGreen;
      routeExpanded = true;
      mapFullScreen = false;
      PlatformBridge.onVictory(
        hapticsEnabled: hapticsEnabled,
        soundEnabled: soundEnabled,
      );
    }
    _resetSelection();
    _saveCurrentState();
    notifyListeners();
  }

  String _arrivalVia() {
    if (_game.legs.isEmpty) return '';
    final lastLeg = _game.legs.last;
    if (!_game.rules.showsConnections() || lastLeg.via.isEmpty) return '';
    final codes = [for (final i in lastLeg.via) _game.net.code(i)].join(', ');
    return ' via $codes';
  }

  void goBack() {
    if (_game.status != GameStatus.playing) return;
    final net = _game.net;
    final left = _game.back();
    if (left != null) {
      statusMessage =
          'Back at ${net.code(_game.current)} (left ${net.code(left)}).';
      statusColor = FlightDeckColors.textSecondary;
      final opts = _game.options();
      final prevChoiceIdx = opts.indexWhere((o) => o.airport == left);
      selectedOptionIndex =
          prevChoiceIdx >= 0 ? prevChoiceIdx : (opts.isNotEmpty ? 0 : null);
      PlatformBridge.onBacktrack(
        hapticsEnabled: hapticsEnabled,
        soundEnabled: soundEnabled,
      );
      _saveCurrentState();
    } else {
      statusMessage = "You're at the start; there's nowhere to go back to.";
      statusColor = FlightDeckColors.warningOrange;
    }
    notifyListeners();
  }

  void startNewGame([Difficulty? newDifficulty]) {
    final targetDifficulty = newDifficulty ?? _game.difficulty;
    final (nextGame, err) = FlightsGame.random(
      difficulty: targetDifficulty,
      networkProvider: networkProvider,
      custom: _game.custom,
      units: _game.units,
      curves: _game.curves,
    );
    if (nextGame != null) {
      _game = nextGame;
      final about = targetDifficulty == Difficulty.custom
          ? _game.rules.summary()
          : targetDifficulty.description;
      routeExpanded = false;
      if (!_game.rules.showsMap()) {
        mapFullScreen = false;
      }
      _afterRestart(
        'New game started!\nDifficulty: ${targetDifficulty.label} ($about).',
      );
    } else {
      statusMessage = err ?? "Can't start game with current settings.";
      statusColor = FlightDeckColors.warningOrange;
      notifyListeners();
    }
  }

  void startDailyGame() {
    _game = FlightsGame.newDaily(
      networkProvider: networkProvider,
      custom: _game.custom,
      units: _game.units,
      curves: _game.curves,
    );
    routeExpanded = false;
    final date = _game.dailyDate ?? 'today';
    _afterRestart(
      'Daily Challenge ($date UTC) started!\nDifficulty: ${_game.difficulty.label}.',
    );
  }

  /// Moves to the next difficulty, past Custom when its settings can't be
  /// played (so the cycle never sticks there, and says why it skipped it).
  void cycleDifficulty() {
    final next = _game.difficulty.next();
    startNewGame(next);
    if (_game.difficulty != next) {
      final skipped = statusMessage;
      startNewGame(next.next());
      statusMessage = '$statusMessage\n(Skipped Custom: $skipped)';
      notifyListeners();
    }
  }

  /// Arrow-key selection: through the options while playing, and once the
  /// game is over (when there are none) through the route's hops.
  void moveSelection(bool down) {
    if (_game.status != GameStatus.playing) {
      stepRouteHop(down);
      return;
    }
    final count = _game.options().length;
    if (count == 0) return;
    final cur = selectedOptionIndex;
    selectedOptionIndex = cur == null
        ? (down ? 0 : count - 1)
        : (down ? math.min(count - 1, cur + 1) : math.max(0, cur - 1));
    if (selectedOptionIndex != cur) {
      PlatformBridge.onPreviewSelect(hapticsEnabled: hapticsEnabled);
    }
    notifyListeners();
  }

  /// Enter / Right arrow: fly to the selected option, or explain why not.
  void submit() {
    if (_game.status != GameStatus.playing) return;
    if (selectedOptionIndex != null && options.isNotEmpty) {
      flyToSelected();
    } else if (_game.atDestination()) {
      statusMessage = 'Go back (← or Backspace) to find a shorter way.';
      statusColor = FlightDeckColors.warningOrange;
      notifyListeners();
    }
  }

  void scrollRoutePages(int pages) => _routePageRequests.add(pages);

  void cycleUnits() {
    final next = _game.units.next();
    _game.units = next;
    statusMessage = 'Distances now in ${next.label}.';
    statusColor = FlightDeckColors.accentSkyBlue;
    _saveCurrentState();
    notifyListeners();
  }

  void triggerGiveUp() {
    if (_game.status != GameStatus.playing) return;
    _game.giveUp();
    _resetSelection();
    routeExpanded = true;
    mapFullScreen = false;
    statusMessage =
        'A shortest route: ${_game.routeText(_game.bestRoute)} (${_game.units.format(_game.bestDistance)})\n${_game.divergenceText()}';
    statusColor = FlightDeckColors.warningOrange;
    _saveCurrentState();
    notifyListeners();
  }

  void _afterRestart(String message) {
    _resetSelection();
    userMapBounds = null;
    statusMessage = message;
    statusColor = FlightDeckColors.accentSkyBlue;
    _saveCurrentState();
    notifyListeners();
  }

  void stepRouteHop(bool down) {
    if (_game.status == GameStatus.playing) return;
    final total = stepCount;
    if (total <= 0) return;
    final last = total - 1;
    final cur = routeStep;
    if (cur == null) {
      routeStep = down ? 0 : last;
    } else {
      routeStep = down ? math.min(last, cur + 1) : math.max(0, cur - 1);
    }
    PlatformBridge.onPreviewSelect(hapticsEnabled: hapticsEnabled);
    notifyListeners();
  }

  void selectRouteHop(int? step) {
    if (_game.status == GameStatus.playing) return;
    final total = stepCount;
    if (step != null && step >= 0 && step < total) {
      routeStep = (routeStep == step) ? null : step;
    } else {
      routeStep = null;
    }
    PlatformBridge.onPreviewSelect(hapticsEnabled: hapticsEnabled);
    notifyListeners();
  }

  void toggleRouteExpanded() {
    routeExpanded = !routeExpanded;
    notifyListeners();
  }

  void toggleMapFullScreen() {
    mapFullScreen = !mapFullScreen;
    notifyListeners();
  }

  String? applySettings({
    required Units units,
    required bool curves,
    required bool haptics,
    required bool sound,
    required ThemeChoice theme,
    required DarkStyle dark,
    required bool oneTap,
    required Rules custom,
    required bool playCustom,
  }) {
    _game.units = units;
    _game.curves = curves;
    hapticsEnabled = haptics;
    soundEnabled = sound;
    themeChoice = theme;
    darkStyle = dark;
    oneTapToFly = oneTap;
    _game.custom = custom;

    if (!playCustom) {
      statusMessage = 'Settings saved.';
      statusColor = FlightDeckColors.accentSkyBlue;
      _saveCurrentState();
      notifyListeners();
      return null;
    }

    final (_, err) = custom.check(networkProvider);
    if (err != null) {
      return "Can't play: $err.";
    }

    startNewGame(Difficulty.custom);
    return null;
  }

  /// Called by the map as it lays out, with its fitted view and its
  /// canvas's width / height. A zoomed or panned view is in degrees, so a
  /// resize (or a pan north or south) would otherwise stretch it; it's
  /// reshaped to the canvas here. No notify: this runs during build.
  void syncViewport(MapBounds fitted, double aspect) {
    lastFittedBounds = fitted;
    final user = userMapBounds;
    if (user != null) userMapBounds = user.withAspect(aspect);
  }

  void zoomMap(
    double factor, {
    double focusFracX = 0.5,
    double focusFracY = 0.5,
  }) {
    final cur = userMapBounds ?? lastFittedBounds;
    final widest = math.max(CoastlineData.maxViewLat, lastFittedBounds.latSpan);
    final newLatSpan = cur.latSpan * factor;
    if (newLatSpan < CoastlineData.minViewLat || newLatSpan > widest) {
      return;
    }
    final cx = cur.lonMin + focusFracX * cur.lonSpan;
    final cy = cur.latMax - focusFracY * cur.latSpan;
    userMapBounds = MapBounds(
      lonMin: cx - (cx - cur.lonMin) * factor,
      lonMax: cx + (cur.lonMax - cx) * factor,
      latMin: cy - (cy - cur.latMin) * factor,
      latMax: cy + (cur.latMax - cy) * factor,
    );
    notifyListeners();
  }

  void transformMap({
    required double zoomFactor,
    required double panFracX,
    required double panFracY,
    required double focusFracX,
    required double focusFracY,
  }) {
    var cur = userMapBounds ?? lastFittedBounds;

    if (panFracX != 0.0 || panFracY != 0.0) {
      final dLon = -panFracX * cur.lonSpan;
      final dLat = panFracY * cur.latSpan;
      cur = MapBounds(
        lonMin: cur.lonMin + dLon,
        lonMax: cur.lonMax + dLon,
        latMin: cur.latMin + dLat,
        latMax: cur.latMax + dLat,
      );
    }

    if (zoomFactor != 1.0) {
      final widest =
          math.max(CoastlineData.maxViewLat, lastFittedBounds.latSpan);
      final double clampedFactor;
      if (cur.latSpan * zoomFactor < CoastlineData.minViewLat) {
        clampedFactor = CoastlineData.minViewLat / cur.latSpan;
      } else if (cur.latSpan * zoomFactor > widest) {
        clampedFactor = widest / cur.latSpan;
      } else {
        clampedFactor = zoomFactor;
      }
      final cx = cur.lonMin + focusFracX * cur.lonSpan;
      final cy = cur.latMax - focusFracY * cur.latSpan;
      cur = MapBounds(
        lonMin: cx - (cx - cur.lonMin) * clampedFactor,
        lonMax: cx + (cur.lonMax - cx) * clampedFactor,
        latMin: cy - (cy - cur.latMin) * clampedFactor,
        latMax: cy + (cur.latMax - cy) * clampedFactor,
      );
    }

    userMapBounds = cur;
    notifyListeners();
  }

  /// Moves the view by fractions of its width (`dx`, east) and height
  /// (`dy`, north).
  void panMap(double dx, double dy) {
    final cur = userMapBounds ?? lastFittedBounds;
    final sx = cur.lonSpan * dx;
    final sy = cur.latSpan * dy;
    userMapBounds = MapBounds(
      lonMin: cur.lonMin + sx,
      lonMax: cur.lonMax + sx,
      latMin: cur.latMin + sy,
      latMax: cur.latMax + sy,
    );
    notifyListeners();
  }

  void fitMap() {
    userMapBounds = null;
    notifyListeners();
  }

  Future<void> shareResults() async {
    final sharedNatively =
        await PlatformBridge.shareText(_game.shareCardText());
    if (!sharedNatively) {
      statusMessage = 'Copied route summary to clipboard!';
      statusColor = FlightDeckColors.accentSkyBlue;
      notifyListeners();
    }
  }
}
