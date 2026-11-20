import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/flights_game.dart';
import 'flights_controller.dart';
import 'theme/flight_deck_theme.dart';
import 'widgets/difficulty_dialog.dart';
import 'widgets/flight_radar_map.dart';
import 'widgets/help_dialog.dart';
import 'widgets/options_panel.dart';
import 'widgets/route_panel.dart';
import 'widgets/settings_dialog.dart';

class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key, required this.controller});

  final FlightsController controller;

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  // Map keyboard steps, matching jotto-cli's TUI.
  static const double _zoomStep = 1.5;
  static const double _panStep = 0.2;

  /// Landscape side column cap: wide enough for an option row with its
  /// distance, city and connections.
  static const double _maxSideColumnWidth = 440;
  static const double _minSideColumnWidth = 300;

  /// Stacked layout options box: the tall-window counterpart of the side
  /// column's cap, about ten option rows.
  static const double _maxOptionsHeight = 380;
  static const double _minOptionsHeight = 120;

  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'FlightsScreen');

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  /// Keyboard controls mirror jotto-cli's `flights` TUI, so the game plays
  /// the same with a hardware keyboard. Ctrl shortcuts also accept Cmd, the
  /// usual modifier on macOS and iPadOS.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ctrl = widget.controller;
    if (!ctrl.keyboardSeen) ctrl.keyboardSeen = true;
    final keyboard = HardwareKeyboard.instance;
    final mod = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;
    final isRepeat = event is KeyRepeatEvent;

    if (mod) {
      // Repeats would start several games from one held key.
      if (isRepeat) return KeyEventResult.ignored;
      final VoidCallback? action = switch (key) {
        LogicalKeyboardKey.keyN => () => ctrl.startNewGame(),
        LogicalKeyboardKey.keyD => ctrl.cycleDifficulty,
        LogicalKeyboardKey.keyT => ctrl.startDailyGame,
        LogicalKeyboardKey.keyG => ctrl.triggerGiveUp,
        LogicalKeyboardKey.keyU => ctrl.cycleUnits,
        LogicalKeyboardKey.keyS => _openSettingsDialog,
        _ => null,
      };
      if (action == null) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      ctrl.moveSelection(false);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      ctrl.moveSelection(true);
    } else if (key == LogicalKeyboardKey.pageUp) {
      ctrl.scrollRoutePages(-1);
    } else if (key == LogicalKeyboardKey.pageDown) {
      ctrl.scrollRoutePages(1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.backspace) {
      ctrl.goBack();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (isRepeat) return KeyEventResult.handled;
      ctrl.submit();
    } else if (key == LogicalKeyboardKey.escape) {
      // jotto-cli quits on Esc; an app shouldn't, so it only leaves full screen.
      if (!ctrl.mapFullScreen) return KeyEventResult.ignored;
      ctrl.toggleMapFullScreen();
    } else {
      return _handleCharacter(event.character);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _handleCharacter(String? character) {
    if (character == null || character.isEmpty) return KeyEventResult.ignored;
    final ctrl = widget.controller;
    if (character == '?') {
      _openHelpDialog();
      return KeyEventResult.handled;
    }
    if (!ctrl.game.rules.showsMap()) return KeyEventResult.ignored;
    switch (character.toLowerCase()) {
      case '+' || '=':
        ctrl.zoomMap(1.0 / _zoomStep);
      case '-' || '_':
        ctrl.zoomMap(_zoomStep);
      case 'w':
        ctrl.panMap(0.0, _panStep);
      case 's':
        ctrl.panMap(0.0, -_panStep);
      case 'a':
        ctrl.panMap(-_panStep, 0.0);
      case 'd':
        ctrl.panMap(_panStep, 0.0);
      case '0':
        ctrl.fitMap();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // Lock phones (shortestSide < 600) to portrait orientation; allow all orientations on iPad / tablets / macOS
    if (shortestSide < 600) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  void _openDifficultyDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => DifficultyDialog(
        controller: widget.controller,
        onOpenCustomSettings: _openSettingsDialog,
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(controller: widget.controller),
    );
  }

  void _openHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => HelpDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final game = ctrl.game;
        final size = MediaQuery.sizeOf(context);
        // Side-by-side only when the window is wider than tall (and wide
        // enough for both columns); anything taller than wide, from a phone
        // to a narrowed Mac window or a portrait iPad, stacks the map on top.
        final isWideLayout = size.width > size.height && size.width >= 760;

        return Focus(
          focusNode: _keyboardFocus,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Scaffold(
            backgroundColor: FlightDeckColors.background,
            body: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ctrl.availableUpdate != null) ...[
                      _UpdateBanner(controller: ctrl),
                      const SizedBox(height: 8),
                    ],
                    _FlightDeckHeader(
                      controller: ctrl,
                      onOpenDifficulty: _openDifficultyDialog,
                      onOpenHelp: _openHelpDialog,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: (ctrl.mapFullScreen && game.rules.showsMap())
                          ? _buildFullScreenMapBody(ctrl)
                          : isWideLayout
                              ? _buildWideSplitBody(ctrl)
                              : _buildPortraitStackedBody(ctrl),
                    ),
                    const SizedBox(height: 8),
                    _FlightDeckBottomBar(
                      controller: ctrl,
                      onOpenSettings: _openSettingsDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullScreenMapBody(FlightsController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FlightRadarMap(
            controller: ctrl,
            isFullScreen: true,
            onToggleFullScreen: ctrl.toggleMapFullScreen,
          ),
        ),
        const SizedBox(height: 8),
        RoutePanel(
          controller: ctrl,
          alwaysExpanded: false,
          maxExpandedHeight: 140,
        ),
      ],
    );
  }

  Widget _buildPortraitStackedBody(FlightsController ctrl) {
    final game = ctrl.game;
    final showsMap = game.rules.showsMap();
    final isPlaying = game.status == GameStatus.playing;

    if (showsMap && isPlaying) return _buildStackedMapBody(ctrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showsMap) ...[
          Expanded(
            flex: 46,
            child: FlightRadarMap(
              controller: ctrl,
              isFullScreen: false,
              onToggleFullScreen: ctrl.toggleMapFullScreen,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _StatusBanner(controller: ctrl),
        const SizedBox(height: 8),
        if (isPlaying) ...[
          Expanded(
            child: OptionsPanel(controller: ctrl),
          ),
          const SizedBox(height: 8),
          RoutePanel(
            controller: ctrl,
            alwaysExpanded: false,
            maxExpandedHeight: 175,
          ),
        ] else
          Expanded(
            flex: 54,
            child: RoutePanel(
              controller: ctrl,
              alwaysExpanded: true,
            ),
          ),
      ],
    );
  }

  /// Stacked layout while playing a level with a map. Like the side column
  /// in the wide layout, the options box has a fixed size for the window,
  /// capped so a tall window gives its extra height to the map. It doesn't
  /// follow the number of options, so the map doesn't jump between hops. On
  /// a phone the cap keeps roughly the old 44/56 map/options split.
  Widget _buildStackedMapBody(FlightsController ctrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The status banner, collapsed route and gaps take about this much;
        // only the split between map and options depends on it.
        const otherParts = 150.0;
        final optionsHeight = ((constraints.maxHeight - otherParts) * 0.56)
            .clamp(_minOptionsHeight, _maxOptionsHeight);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FlightRadarMap(
                controller: ctrl,
                isFullScreen: false,
                onToggleFullScreen: ctrl.toggleMapFullScreen,
              ),
            ),
            const SizedBox(height: 8),
            _StatusBanner(controller: ctrl),
            const SizedBox(height: 8),
            SizedBox(
              height: optionsHeight,
              child: OptionsPanel(controller: ctrl),
            ),
            const SizedBox(height: 8),
            RoutePanel(
              controller: ctrl,
              alwaysExpanded: false,
              maxExpandedHeight: 175,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideSplitBody(FlightsController ctrl) {
    final game = ctrl.game;
    final showsMap = game.rules.showsMap();
    final isPlaying = game.status == GameStatus.playing;

    if (showsMap) {
      // The map is the main thing to look at, so the side column gets a
      // third of the width, at least enough for an option row to stay
      // legible and never more than it needs; every other pixel goes to
      // the map.
      return LayoutBuilder(
        builder: (context, constraints) {
          final total = constraints.maxWidth - 8;
          final sideWidth =
              (total * 0.34).clamp(_minSideColumnWidth, _maxSideColumnWidth);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FlightRadarMap(
                  controller: ctrl,
                  isFullScreen: false,
                  onToggleFullScreen: ctrl.toggleMapFullScreen,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: sideWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusBanner(controller: ctrl),
                    const SizedBox(height: 8),
                    if (isPlaying) ...[
                      Expanded(
                        flex: 58,
                        child: OptionsPanel(controller: ctrl),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: 42,
                        child: RoutePanel(
                          controller: ctrl,
                          alwaysExpanded: true,
                        ),
                      ),
                    ] else
                      Expanded(
                        child: RoutePanel(
                          controller: ctrl,
                          alwaysExpanded: true,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OptionsPanel(controller: ctrl),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(controller: ctrl),
                const SizedBox(height: 8),
                Expanded(
                  child: RoutePanel(
                    controller: ctrl,
                    alwaysExpanded: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}

class _FlightDeckHeader extends StatelessWidget {
  const _FlightDeckHeader({
    required this.controller,
    required this.onOpenDifficulty,
    required this.onOpenHelp,
  });

  final FlightsController controller;
  final VoidCallback onOpenDifficulty;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final font = FlightDeckColors.monospaceFontFamily;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // A Daily game's badge pushes this past the width of phones under
          // ~410pt, so the title group shrinks rather than overflowing.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FLIGHTS',
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.2,
                      color: FlightDeckColors.textPrimary,
                    ),
                  ),
                  if (game.dailyDate != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: FlightDeckColors.accentSkyBlue
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: FlightDeckColors.accentSkyBlue.withValues(
                            alpha: 0.6,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'DAILY',
                        style: TextStyle(
                          fontFamily: font,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          color: FlightDeckColors.accentSkyBlue,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlightDeckColors.radarBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: FlightDeckColors.borderAccent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.startCode,
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FlightDeckColors.textPrimary,
                          ),
                        ),
                        Text(
                          ' → ',
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 12,
                            color: FlightDeckColors.textMuted,
                          ),
                        ),
                        Text(
                          '${game.endCode}★',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FlightDeckColors.destinationPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onOpenDifficulty,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlightDeckColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: FlightDeckColors.accentSkyBlue.withValues(
                        alpha: 0.6,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${game.difficulty.label} ▾',
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: FlightDeckColors.accentSkyBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: controller.cycleUnits,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlightDeckColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: FlightDeckColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    game.distancesVisible()
                        ? game.units.format(game.totalDistance())
                        : game.units.label,
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: FlightDeckColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onOpenHelp,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlightDeckColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: FlightDeckColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: FlightDeckColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.controller});
  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final net = controller.currentNetwork;
    final font = FlightDeckColors.monospaceFontFamily;
    final currentPlace = net.place(game.current);
    final endPlace = net.place(game.destination);

    final currentInfo = StringBuffer('At ${game.currentCode}');
    if (game.rules.showPlaces && currentPlace.isNotEmpty) {
      currentInfo.write(' ($currentPlace)');
    }
    final destInfo = StringBuffer('Target: ${game.endCode}');
    if (game.rules.showPlaces && endPlace.isNotEmpty) {
      destInfo.write(' ($endPlace)');
    }

    final borderColor = switch (game.status) {
      GameStatus.won => FlightDeckColors.positiveGreen.withValues(alpha: 0.7),
      GameStatus.givenUp =>
        FlightDeckColors.warningOrange.withValues(alpha: 0.7),
      GameStatus.playing => FlightDeckColors.borderSubtle,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentInfo.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: FlightDeckColors.positiveGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  destInfo.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: FlightDeckColors.destinationPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.statusMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: controller.statusColor,
                  ),
                ),
              ),
              if (game.status == GameStatus.won) ...[
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: controller.shareResults,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: FlightDeckColors.positiveGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Share',
                      style: TextStyle(
                        fontFamily: font,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: FlightDeckColors.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FlightDeckBottomBar extends StatelessWidget {
  const _FlightDeckBottomBar({
    required this.controller,
    required this.onOpenSettings,
  });

  final FlightsController controller;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: _BottomActionButton(
              label: 'New Game',
              accentColor: FlightDeckColors.accentSkyBlue,
              onTap: () => controller.startNewGame(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 9,
            child: _BottomActionButton(
              label: 'Daily',
              accentColor: game.dailyDate != null
                  ? FlightDeckColors.positiveGreen
                  : FlightDeckColors.textPrimary,
              onTap: controller.startDailyGame,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: game.status == GameStatus.playing
                ? _BottomActionButton(
                    label: 'Give Up',
                    accentColor: FlightDeckColors.warningOrange,
                    onTap: controller.triggerGiveUp,
                  )
                : _BottomActionButton(
                    label: 'Share',
                    accentColor: FlightDeckColors.positiveGreen,
                    onTap: controller.shareResults,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: _BottomActionButton(
              label: 'Settings',
              accentColor: FlightDeckColors.textSecondary,
              onTap: onOpenSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    return Material(
      color: FlightDeckColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: font,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line note that a newer release is out, with a link to it. Slim and
/// dismissible, so it never pushes the game around for long.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.controller});

  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    final update = controller.availableUpdate!;
    final accent = FlightDeckColors.accentSkyBlue;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Flights ${update.version} is available',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: FlightDeckColors.textPrimary,
                fontFamily: FlightDeckColors.monospaceFontFamily,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.openUpdate,
            style: TextButton.styleFrom(foregroundColor: accent),
            child: Text(
              'Get it',
              style: TextStyle(
                fontFamily: FlightDeckColors.monospaceFontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: controller.dismissUpdate,
            icon: Icon(Icons.close, size: 16, color: FlightDeckColors.textMuted),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
