import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/main.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/flights_screen.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
import 'package:flights/ui/widgets/flight_radar_map.dart';
import 'package:flights/ui/widgets/options_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FlightsRepository repo;

  setUpAll(() {
    repo = FlightsRepository(
      rawFlightsTsv: File('assets/flights.tsv').readAsStringSync(),
      coastlines: CoastlineData.parse(
        File('assets/coastlines.bin').readAsBytesSync(),
      ),
    );
  });

  tearDown(() => FlightDeckColors.current = FlightDeckPalette.navy);

  test('palette follows the theme setting and device brightness', () {
    const r = FlightDeckPalette.resolve;
    expect(
      r(ThemeChoice.system, DarkStyle.navy, Brightness.light),
      FlightDeckPalette.light,
    );
    expect(
      r(ThemeChoice.system, DarkStyle.navy, Brightness.dark),
      FlightDeckPalette.navy,
    );
    expect(
      r(ThemeChoice.system, DarkStyle.black, Brightness.dark),
      FlightDeckPalette.black,
    );
    expect(
      r(ThemeChoice.light, DarkStyle.black, Brightness.dark),
      FlightDeckPalette.light,
    );
    expect(
      r(ThemeChoice.dark, DarkStyle.black, Brightness.light),
      FlightDeckPalette.black,
    );
  });

  test('unknown or missing saved theme names fall back to defaults', () {
    expect(ThemeChoice.fromName(null), ThemeChoice.system);
    expect(ThemeChoice.fromName('neon'), ThemeChoice.system);
    expect(DarkStyle.fromName('black'), DarkStyle.black);
    expect(DarkStyle.fromName(null), DarkStyle.navy);
  });

  FlightsController newController() => FlightsController(
        repository: repo,
        initialGame: FlightsGame.newDaily(networkProvider: repo.network),
        initialMessage: 'test',
        initialMessageColor: FlightDeckColors.textSecondary,
        hapticsEnabled: false,
        soundEnabled: false,
      );

  testWidgets('each palette paints the screen background', (tester) async {
    for (final palette in [
      FlightDeckPalette.light,
      FlightDeckPalette.black,
      FlightDeckPalette.navy,
    ]) {
      FlightDeckColors.current = palette;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(palette),
          home: FlightsScreen(controller: newController()),
        ),
      );
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, palette.background);
    }
  });

  testWidgets('landscape side column stops growing; the map takes the rest',
      (tester) async {
    for (final size in const [Size(1180, 760), Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(size),
          home: FlightsScreen(controller: newController()),
        ),
      );
      await tester.pump();
      final side = tester.getSize(find.byType(OptionsPanel)).width;
      final map = tester.getSize(find.byType(FlightRadarMap)).width;
      expect(side, lessThanOrEqualTo(440));
      expect(map, greaterThan(size.width * 0.6));
    }
    tester.view.reset();
  });

  testWidgets('taller than wide stacks the map on top; wider sits beside',
      (tester) async {
    final ctrl = newController();
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(MaterialApp(home: FlightsScreen(controller: ctrl)));

    // Narrowing the same window, down to the Mac minimum, switches layout.
    for (final (size, stacked) in const [
      (Size(1200, 800), false),
      (Size(820, 1180), true),
      (Size(780, 900), true),
      (Size(380, 520), true),
      (Size(1200, 800), false),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      final map = tester.getRect(find.byType(FlightRadarMap));
      final options = tester.getRect(find.byType(OptionsPanel));
      if (stacked) {
        expect(map.bottom, lessThanOrEqualTo(options.top), reason: '$size');
      } else {
        expect(map.right, lessThanOrEqualTo(options.left), reason: '$size');
      }
    }
  });

  testWidgets('tall windows give the map the height the options do not need',
      (tester) async {
    final ctrl = newController();
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(820, 1400);
    await tester.pumpWidget(MaterialApp(home: FlightsScreen(controller: ctrl)));
    await tester.pump();
    final options = tester.getSize(find.byType(OptionsPanel)).height;
    final map = tester.getSize(find.byType(FlightRadarMap)).height;
    expect(options, lessThanOrEqualTo(380));
    expect(map, greaterThan(700));
  });

  testWidgets('changing the theme in Settings repaints the app and saves it',
      (tester) async {
    String? saved;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('me.guslipkin.flights/platform'),
      (call) async {
        if (call.method == 'writeSave') {
          saved = (call.arguments as Map)['content'] as String;
        }
        return null;
      },
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const FlightsApp());
    // Loading the network data is real async work.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    Color background() =>
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
    expect(background(), FlightDeckPalette.navy.background);

    final screen = tester.widget<FlightsScreen>(find.byType(FlightsScreen));
    final ctrl = screen.controller;
    void apply(ThemeChoice theme, DarkStyle dark) => ctrl.applySettings(
          units: ctrl.game.units,
          curves: ctrl.game.curves,
          haptics: false,
          sound: false,
          theme: theme,
          dark: dark,
          oneTap: false,
          custom: ctrl.game.custom,
          playCustom: false,
        );

    apply(ThemeChoice.light, DarkStyle.navy);
    await tester.pump();
    expect(background(), FlightDeckPalette.light.background);

    apply(ThemeChoice.system, DarkStyle.black);
    await tester.pump();
    expect(background(), FlightDeckPalette.black.background);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(saved, contains('"theme":"system"'));
    expect(saved, contains('"dark_style":"black"'));

    // The System theme follows the device as it changes.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(background(), FlightDeckPalette.light.background);
  });
}
