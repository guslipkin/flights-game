import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/flights_screen.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
import 'package:flights/ui/widgets/flight_radar_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapBounds.withAspect', () {
    const view = MapBounds(lonMin: -10, lonMax: 30, latMin: 35, latMax: 60);

    test('matches the canvas shape, keeping center and area', () {
      for (final aspect in [0.5, 1.0, 1.7, 3.0]) {
        final r = view.withAspect(aspect);
        expect(r.aspect, closeTo(aspect, 1e-9));
        expect(r.centerLon, closeTo(view.centerLon, 1e-9));
        expect(r.centerLat, closeTo(view.centerLat, 1e-9));
        expect(
            r.lonSpan * r.latSpan, closeTo(view.lonSpan * view.latSpan, 1e-6));
      }
    });

    test('resizing back returns the original view', () {
      final original = view.withAspect(1.5);
      final back = original.withAspect(0.6).withAspect(2.4).withAspect(1.5);
      expect(back.lonMin, closeTo(original.lonMin, 1e-9));
      expect(back.lonMax, closeTo(original.lonMax, 1e-9));
      expect(back.latMin, closeTo(original.latMin, 1e-9));
      expect(back.latMax, closeTo(original.latMax, 1e-9));
    });

    test('a view already the right shape is unchanged', () {
      final fitted = view.withAspect(1.3);
      expect(identical(fitted.withAspect(1.3), fitted), isTrue);
    });
  });

  testWidgets('a zoomed map is not squished when the window is resized',
      (tester) async {
    final repo = FlightsRepository(
      rawFlightsTsv: File('assets/flights.tsv').readAsStringSync(),
      coastlines: CoastlineData.parse(
        File('assets/coastlines.bin').readAsBytesSync(),
      ),
    );
    final ctrl = FlightsController(
      repository: repo,
      initialGame: FlightsGame.newDaily(networkProvider: repo.network),
      initialMessage: 'test',
      initialMessageColor: FlightDeckColors.textSecondary,
      hapticsEnabled: false,
      soundEnabled: false,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The view the map drew and its canvas's shape must agree for the
    // drawing to be undistorted.
    void expectUndistorted() {
      final size = tester.getSize(find.byType(FlightRadarMap));
      // The map has a 1px border on each side.
      final aspect = (size.width - 2) / (size.height - 2);
      final shown = ctrl.userMapBounds ?? ctrl.lastFittedBounds;
      expect(shown.aspect, closeTo(aspect, aspect * 1e-6));
    }

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpWidget(MaterialApp(home: FlightsScreen(controller: ctrl)));
    await tester.pump();
    expectUndistorted();

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(ctrl.userMapBounds, isNotNull);
    expectUndistorted();
    final zoomed = ctrl.userMapBounds!;

    for (final size in const [
      Size(1000, 900),
      Size(2200, 900),
      Size(1600, 1400),
      Size(1600, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expectUndistorted();
      // Still looking at the same place.
      expect(ctrl.userMapBounds!.centerLon, closeTo(zoomed.centerLon, 1e-6));
      expect(ctrl.userMapBounds!.centerLat, closeTo(zoomed.centerLat, 1e-6));
    }
    // Back at the starting size, the view is the one the player left.
    expect(
      ctrl.userMapBounds!.latSpan,
      closeTo(zoomed.latSpan, zoomed.latSpan * 1e-6),
    );
  });
}
