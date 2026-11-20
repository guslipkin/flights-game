import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/flights_screen.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
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

  FlightsController newController() {
    final game = FlightsGame.newDaily(networkProvider: repo.network);
    return FlightsController(
      repository: repo,
      initialGame: game,
      initialMessage: 'test',
      initialMessageColor: FlightDeckColors.textSecondary,
      hapticsEnabled: false,
      soundEnabled: false,
    );
  }

  Future<FlightsController> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ctrl = newController();
    await tester.pumpWidget(
      MaterialApp(home: FlightsScreen(controller: ctrl)),
    );
    await tester.pump();
    return ctrl;
  }

  testWidgets('arrow keys, Enter and Left play the game', (tester) async {
    final ctrl = await pumpScreen(tester, const Size(1200, 800));
    expect(ctrl.options.length, greaterThan(1));
    expect(ctrl.selectedOptionIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(ctrl.selectedOptionIndex, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(ctrl.selectedOptionIndex, 0);

    final target = ctrl.options[0].airport;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(ctrl.game.route.length, 2);
    expect(ctrl.game.current, target);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(ctrl.game.route.length, 1);
  });

  testWidgets('map keys zoom, pan and fit', (tester) async {
    final ctrl = await pumpScreen(tester, const Size(1200, 800));
    expect(ctrl.userMapBounds, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    final zoomed = ctrl.userMapBounds!;
    expect(zoomed.latSpan, lessThan(ctrl.lastFittedBounds.latSpan));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(ctrl.userMapBounds!.lonMin, greaterThan(zoomed.lonMin));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(ctrl.userMapBounds, isNull);
  });

  testWidgets('Ctrl and Cmd shortcuts', (tester) async {
    final ctrl = await pumpScreen(tester, const Size(1200, 800));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(ctrl.game.status, GameStatus.givenUp);

    // Once the game is over, the arrows step through the route's hops.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(ctrl.routeStep, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(ctrl.game.status, GameStatus.playing);
    expect(ctrl.game.dailyDate, isNull);

    final before = ctrl.game.difficulty;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(ctrl.game.difficulty, isNot(before));
  });

  testWidgets('? opens help, wider in landscape, with the key list',
      (tester) async {
    await pumpScreen(tester, const Size(1200, 800));
    await tester.sendKeyEvent(
      LogicalKeyboardKey.slash,
      character: '?',
    );
    await tester.pumpAndSettle();
    expect(find.text('Keyboard & mouse'), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(480));
  });

  testWidgets('dialogs keep their phone width in portrait', (tester) async {
    await pumpScreen(tester, const Size(400, 860));
    await tester.sendKeyEvent(
      LogicalKeyboardKey.slash,
      character: '?',
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(480));
  });
}
