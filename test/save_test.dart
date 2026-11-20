import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FlightsRepository repo;

  // Stands in for the native save file. It reads the text from 'content',
  // as the Android, iOS and macOS handlers do, so a mismatched key between
  // Dart and native fails here instead of silently saving nothing.
  String? file;

  setUpAll(() {
    repo = FlightsRepository(
      rawFlightsTsv: File('assets/flights.tsv').readAsStringSync(),
      coastlines: CoastlineData.parse(
        File('assets/coastlines.bin').readAsBytesSync(),
      ),
    );
  });

  setUp(() {
    file = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('me.guslipkin.flights/platform'),
      (call) async {
        switch (call.method) {
          case 'readSave':
            return file;
          case 'writeSave':
            file = ((call.arguments as Map)['content'] as String?) ?? '';
            return true;
        }
        return null;
      },
    );
  });

  // Saves are written without awaiting, so let the channel call land.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  // What a relaunch sees: a new controller built from the saved file.
  Future<FlightsController> relaunch() async {
    await settle();
    return FlightsController.create(repo);
  }

  void applySettings(FlightsController ctrl, {Rules? custom, bool play = false}) {
    ctrl.applySettings(
      units: Units.km,
      curves: false,
      haptics: false,
      sound: false,
      theme: ThemeChoice.light,
      dark: DarkStyle.black,
      oneTap: true,
      custom: custom ?? ctrl.game.custom,
      playCustom: play,
    );
  }

  test('a game in progress is resumed where it was left', () async {
    final first = await FlightsController.create(repo);
    first.flyToSelected();
    final route = [for (final i in first.game.route) first.game.net.code(i)];
    expect(route.length, 2);
    expect(file, isNotEmpty);

    final second = await relaunch();
    expect(second.game.startCode, first.game.startCode);
    expect(second.game.endCode, first.game.endCode);
    expect(
      [for (final i in second.game.route) second.game.net.code(i)],
      route,
    );
  });

  test('settings and custom rules survive a relaunch', () async {
    final first = await FlightsController.create(repo);
    const custom = Rules(maxHops: 5, showPlaces: false);
    applySettings(first, custom: custom);

    final second = await relaunch();
    expect(second.game.units, Units.km);
    expect(second.game.curves, isFalse);
    expect(second.hapticsEnabled, isFalse);
    expect(second.soundEnabled, isFalse);
    expect(second.themeChoice, ThemeChoice.light);
    expect(second.darkStyle, DarkStyle.black);
    expect(second.oneTapToFly, isTrue);
    expect(second.game.custom.maxHops, 5);
    expect(second.game.custom.showPlaces, isFalse);
  });

  test('a custom game in progress keeps its rules', () async {
    final first = await FlightsController.create(repo);
    applySettings(first, custom: const Rules(maxHops: 5), play: true);
    expect(first.game.difficulty, Difficulty.custom);

    final second = await relaunch();
    expect(second.game.difficulty, Difficulty.custom);
    expect(second.game.startCode, first.game.startCode);
    expect(second.game.rules.maxHops, 5);
  });

  test('after a finished game, the next launch deals at the chosen level',
      () async {
    final first = await FlightsController.create(repo);
    first.startNewGame(Difficulty.hard);
    first.triggerGiveUp();
    expect(first.game.status, GameStatus.givenUp);

    final second = await relaunch();
    expect(second.game.status, GameStatus.playing);
    expect(second.game.difficulty, Difficulty.hard);
    expect(second.preferredDifficulty, Difficulty.hard);
  });

  test("playing the daily doesn't change the chosen level", () async {
    final first = await FlightsController.create(repo);
    first.startNewGame(Difficulty.pilot);
    first.startDailyGame();
    expect(first.game.difficulty, Difficulty.medium);
    first.triggerGiveUp();

    final second = await relaunch();
    expect(second.game.difficulty, Difficulty.pilot);
    // New Game after the daily goes back to the chosen level too.
    first.startNewGame();
    expect(first.game.difficulty, Difficulty.pilot);
  });
}
