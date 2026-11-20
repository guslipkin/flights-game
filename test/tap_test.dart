import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/flights_screen.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
import 'package:flights/ui/widgets/options_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  Future<FlightsController> pump(
    WidgetTester tester, {
    bool oneTap = false,
    Size size = const Size(1200, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ctrl = FlightsController(
      repository: repo,
      initialGame: FlightsGame.newDaily(networkProvider: repo.network),
      initialMessage: 'test',
      initialMessageColor: FlightDeckColors.textSecondary,
      hapticsEnabled: false,
      soundEnabled: false,
      oneTapToFly: oneTap,
    );
    await tester.pumpWidget(MaterialApp(home: FlightsScreen(controller: ctrl)));
    await tester.pump();
    return ctrl;
  }

  Finder optionRow(int i) => find
      .descendant(of: find.byType(OptionsPanel), matching: find.byType(InkWell))
      .at(i);

  testWidgets('touch: first tap previews, second tap flies (default)',
      (tester) async {
    final ctrl = await pump(tester);
    final target = ctrl.options[1].airport;
    await tester.tap(optionRow(1));
    await tester.pump();
    expect(ctrl.selectedOptionIndex, 1);
    expect(ctrl.game.route.length, 1);
    await tester.tap(optionRow(1));
    await tester.pump();
    expect(ctrl.game.current, target);
  });

  testWidgets('touch with One tap: the first tap flies', (tester) async {
    final ctrl = await pump(tester, oneTap: true);
    final target = ctrl.options[1].airport;
    await tester.tap(optionRow(1));
    await tester.pump();
    expect(ctrl.game.current, target);
  });

  testWidgets('mouse: the first click flies, whatever the setting',
      (tester) async {
    final ctrl = await pump(tester);
    final target = ctrl.options[1].airport;
    await tester.tap(optionRow(1), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(ctrl.game.current, target);
  });

  testWidgets('portrait options box keeps its size as options change',
      (tester) async {
    final ctrl = await pump(tester, size: const Size(820, 1180));
    final before = tester.getSize(find.byType(OptionsPanel)).height;
    final countBefore = ctrl.options.length;
    for (var i = 0; i < 2; i++) {
      ctrl.flyToSelected();
      await tester.pump();
    }
    expect(ctrl.options.length, isNot(countBefore));
    expect(tester.getSize(find.byType(OptionsPanel)).height, before);
    expect(before, lessThanOrEqualTo(380));
  });
}
