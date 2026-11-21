import 'dart:io';

import 'package:flutter/material.dart';

import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key, required this.controller});

  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final custom = game.custom;
    final font = FlightDeckColors.monospaceFontFamily;

    final customDesc = custom.fixedRoute
        ? 'your route (Settings)'
        : '${custom.hopsText()}, ${custom.maxConnections} conn. (Settings)';
    final customCountNum = custom.puzzleCount(controller.networkProvider);
    final customCount = custom.countIsExact()
        ? grouped(customCountNum)
        : '≤${grouped(customCountNum)}';

    final levelRows = <(String, String, String)>[
      for (final d in Difficulty.standard)
        (
          d.label,
          d.description,
          grouped(d.puzzleCount(controller.networkProvider)),
        ),
      ('Custom', customDesc, customCount),
    ];

    return Dialog(
      insetPadding: DialogSizing.insetPadding(context),
      backgroundColor: FlightDeckColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: FlightDeckColors.accentSkyBlue,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: DialogSizing.maxWidth(context, 480), maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Wraps rather than overflowing on phones under ~400pt wide.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOW TO PLAY — FLIGHTS',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: FlightDeckColors.accentSkyBlue,
                          ),
                        ),
                        Text(
                          'the shortest way, one letter at a time',
                          style: TextStyle(
                            fontSize: 12,
                            color: FlightDeckColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                        '✕ Close',
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 12,
                          color: FlightDeckColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HelpSectionTitle('Rules', font: font),
                      const SizedBox(height: 4),
                      _HelpBullet(
                        'Each hop changes one letter of the code: LAX → LAS → LOS.',
                        font: font,
                      ),
                      _HelpBullet(
                        'A hop needs a ticket, direct or 1 connection; every leg counts toward the great-circle distance.',
                        font: font,
                      ),
                      _HelpBullet(
                        "Reach the destination the long way and you'll be told; go back to improve.",
                        font: font,
                      ),
                      if (game.rules.oncePerAirport())
                        _HelpBullet(
                          'This game uses each airport once, connections included.',
                          font: font,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: FlightDeckColors.borderSubtle,
                        ),
                      ),
                      _HelpSectionTitle('Controls', font: font),
                      const SizedBox(height: 4),
                      if (controller.oneTapToFly)
                        _HelpBullet(
                          'Tap an option row (or an orange airport on the map) to fly there. Two-tap preview can be turned on in Settings → Tap to fly.',
                          font: font,
                        )
                      else ...[
                        _HelpBullet(
                          'Tap an option row (or an orange airport on the map) once to preview its hop arc on the map.',
                          font: font,
                        ),
                        _HelpBullet(
                          'Tap the selected option again or press Fly to fly there. (Settings → Tap to fly can make one tap fly.)',
                          font: font,
                        ),
                      ],
                      _HelpBullet(
                        'Tap Go Back in the Route panel to undo your last hop.',
                        font: font,
                      ),
                      _HelpBullet(
                        'Pinch or scroll to zoom, drag to pan, double-tap to zoom in, tap Fit to re-center, or tap Full to expand the map.',
                        font: font,
                      ),
                      _HelpBullet(
                        'Once a game is over, tap any hop row or use Prev Hop / Next Hop to step through the route on the map.',
                        font: font,
                      ),
                      // Touch-only devices have no use for key lists, so
                      // these show on desktops or once a hardware key is used.
                      if (Platform.isMacOS ||
                          Platform.isWindows ||
                          controller.keyboardSeen) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            height: 1,
                            color: FlightDeckColors.borderSubtle,
                          ),
                        ),
                        _HelpSectionTitle('Keyboard & mouse', font: font),
                        const SizedBox(height: 4),
                        for (final (keys, what) in _keyboardRows)
                          _HelpKeyRow(keys: keys, what: what, font: font),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: FlightDeckColors.borderSubtle,
                        ),
                      ),
                      _HelpSectionTitle('Difficulty · puzzles', font: font),
                      const SizedBox(height: 6),
                      for (final (name, desc, count) in levelRows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: FlightDeckColors.surfaceElevated
                                  .withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontFamily: font,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: FlightDeckColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: FlightDeckColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  count,
                                  style: TextStyle(
                                    fontFamily: font,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: FlightDeckColors.positiveGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: FlightDeckColors.borderSubtle,
                        ),
                      ),
                      _HelpSectionTitle('Credits', font: font),
                      const SizedBox(height: 4),
                      _HelpBullet(
                        'Flights is an original game conceived and created by Gus Lipkin (guslipkin.me).',
                        font: font,
                      ),
                      _HelpBullet(
                        "Routes: English Wikipedia's airport articles (CC BY-SA 4.0).",
                        font: font,
                      ),
                      _HelpBullet(
                        'Airports & coordinates: OurAirports (public domain).',
                        font: font,
                      ),
                      _HelpBullet(
                        'Map coastlines: Natural Earth (public domain).',
                        font: font,
                      ),
                      _HelpBullet(
                        "Jet audio: Wikimedia Commons ('Jet airliner overhead' & InspectorJ 'Boeing flyby', CC BY 4.0).",
                        font: font,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same keys as jotto-cli's `flights` TUI. Ctrl shortcuts also take Cmd.
const List<(String, String)> _keyboardRows = [
  ('↑ ↓', 'Select an option (or a hop, once the game is over)'),
  ('→ / Enter', 'Fly to the selected option'),
  ('← / Backspace', 'Go back a hop'),
  ('PgUp PgDn', 'Scroll the route'),
  ('+ −', 'Zoom the map'),
  ('W A S D', 'Pan the map'),
  ('0', 'Fit the map to the route again'),
  ('Esc', 'Leave full-screen map'),
  ('Ctrl/⌘ N', 'New game'),
  ('Ctrl/⌘ T', "Today's Daily Challenge"),
  ('Ctrl/⌘ D', 'Next difficulty'),
  ('Ctrl/⌘ G', 'Give up'),
  ('Ctrl/⌘ U', 'Change distance units'),
  ('Ctrl/⌘ S', 'Settings'),
  ('?', 'This help'),
  (
    'Mouse',
    'Click an option or orange airport to fly there; wheel zooms and drag pans the map'
  ),
];

class _HelpKeyRow extends StatelessWidget {
  const _HelpKeyRow(
      {required this.keys, required this.what, required this.font});
  final String keys;
  final String what;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              keys,
              style: TextStyle(
                fontFamily: font,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: FlightDeckColors.warningOrange,
              ),
            ),
          ),
          Expanded(
            child: Text(
              what,
              style: TextStyle(
                fontSize: 12,
                color: FlightDeckColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSectionTitle extends StatelessWidget {
  const _HelpSectionTitle(this.title, {required this.font});
  final String title;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: FlightDeckColors.accentSkyBlue,
      ),
    );
  }
}

class _HelpBullet extends StatelessWidget {
  const _HelpBullet(this.text, {required this.font});
  final String text;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontFamily: font,
              fontSize: 12,
              color: FlightDeckColors.accentSkyBlue,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: FlightDeckColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
