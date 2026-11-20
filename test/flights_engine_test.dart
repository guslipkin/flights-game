import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/fastrand.dart';
import 'package:flights/data/network.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String flightsTsvText;
  late Network net1;

  setUpAll(() {
    flightsTsvText = File('assets/flights.tsv').readAsStringSync();
    net1 = Network.parse(flightsTsvText, 1);
  });

  test('Fastrand matches Rust fastrand 2.5.0 bit-for-bit', () {
    final rng = Fastrand.fromInt(7);
    expect(
      rng.genU64(),
      equals(BigInt.parse('14266376187910451857')),
    );
    expect(Fastrand.formatUtcDate(19723), equals('2024-01-01'));
    expect(Fastrand.formatUtcDate(20776), equals('2026-11-19'));
  });

  test('Network parses airports and bridges accurately', () {
    expect(net1.length, equals(3868));
    expect(net1.bridgeCount, equals(841));
    expect(net1.puzzleCount(const HopRange(min: 3, max: 4)), greaterThan(0));
    expect(
      net1.puzzleCount(const HopRange(min: 3, max: 6)),
      greaterThan(net1.puzzleCount(const HopRange(min: 3, max: 4))),
    );
  });

  test('Daily puzzle matches jotto-cli bit-for-bit', () {
    final mediumRange = Rules.standard(Difficulty.medium).hopRange();

    // Day 19723 (2024-01-01 UTC): OUD -> WYS (7,400 nm)
    final p1 = net1.dailyPuzzle(19723, mediumRange);
    expect(p1, isNotNull);
    expect(net1.code(p1!.$1), equals('OUD'));
    expect(net1.code(p1.$2), equals('WYS'));
    final s1 = net1.shortest(p1.$1, p1.$2)!;
    expect(s1.$1.round(), equals(7400));
    expect(
      [for (final i in s1.$2) net1.code(i)],
      equals(['OUD', 'BUD', 'BOD', 'BOS', 'COS', 'CYS', 'WYS']),
    );

    // Day 20000: SYX -> TLL (6,388 nm)
    final p2 = net1.dailyPuzzle(20000, mediumRange);
    expect(p2, isNotNull);
    expect(net1.code(p2!.$1), equals('SYX'));
    expect(net1.code(p2.$2), equals('TLL'));
    final s2 = net1.shortest(p2.$1, p2.$2)!;
    expect(s2.$1.round(), equals(6388));
    expect(
      [for (final i in s2.$2) net1.code(i)],
      equals(['SYX', 'SZX', 'TZX', 'TZL', 'TLL']),
    );

    // Day 20776 (2026-11-19 UTC): LEX -> CAY (6,635 nm)
    final p3 = net1.dailyPuzzle(20776, mediumRange);
    expect(p3, isNotNull);
    expect(net1.code(p3!.$1), equals('LEX'));
    expect(net1.code(p3.$2), equals('CAY'));
    final s3 = net1.shortest(p3.$1, p3.$2)!;
    expect(s3.$1.round(), equals(6635));
    expect(
      [for (final i in s3.$2) net1.code(i)],
      equals(['LEX', 'LAX', 'LAP', 'SAP', 'CAP', 'CAY']),
    );
  });

  test('Coastlines three scales and geometry match jotto-cli', () {
    final bytes = File('assets/coastlines.bin').readAsBytesSync();
    final coastlines = CoastlineData.parse(bytes);
    expect(coastlines.scales.length, equals(3));

    final pointCounts = [
      for (final scale in coastlines.scales)
        scale.fold<int>(0, (acc, line) => acc + line.length),
    ];
    expect(pointCounts[0], lessThan(pointCounts[1]));
    expect(pointCounts[1], lessThan(pointCounts[2]));
    expect(pointCounts[2], greaterThan(300000));

    const b = MapBounds(lonMin: 0.0, lonMax: 10.0, latMin: 0.0, latMax: 10.0);
    expect(CoastlineData.clip(1.0, 1.0, 9.0, 9.0, b), isNotNull);
    final clipped = CoastlineData.clip(-10.0, 5.0, 5.0, 5.0, b)!;
    expect(clipped.ax, closeTo(0.0, 1e-9));
    expect(clipped.bx, closeTo(5.0, 1e-9));
    expect(CoastlineData.clip(-5.0, -5.0, -1.0, 20.0, b), isNull);

    final nycToLon = CoastlineData.legPoints(
      const LonLat(-73.8, 40.6),
      const LonLat(-0.5, 51.5),
      true,
    );
    expect(
      nycToLon.map((p) => p.lat).reduce((a, b) => a > b ? a : b),
      greaterThan(53.0),
    );
  });

  test('Gameplay longer route, backtracking, victory, and save/restore', () {
    const sampleTsv = '''
A\tAAA\t0\t0\tAlpha\tAA
A\tABA\t0\t10\tBravo\tBB
A\tABB\t0\t20\tCharlie\tCC
A\tBAA\t10\t0\tDelta\tDD
A\tBBA\t10\t15\tEcho\tEE
A\tBBB\t0\t30\tFoxtrot\tFF
H\tAAA\tABA\t-\t-\t-
H\tABA\tABB\t-\t-\t-
H\tABB\tBBB\t-\t-\t-
H\tAAA\tBAA\t-\t-\t-
H\tBAA\tBBA\t-\t-\t-
H\tBBA\tBBB\t-\t-\t-
''';
    final smallNet = Network.parse(sampleTsv, 1);
    final start = smallNet.indexOf('AAA')!;
    final end = smallNet.indexOf('BBB')!;

    final game = FlightsGame.withPuzzle(
      net: smallNet,
      start: start,
      end: end,
      difficulty: Difficulty.medium,
    )!;

    expect(game.fly('BAA').$1, isA<FlewOutcome>());
    expect(game.fly('BBA').$1, isA<FlewOutcome>());

    final savedJson = game.toSavedJson();
    final restored = FlightsGame.fromSavedJson(savedJson, (_) => smallNet)!;
    expect(
      [for (final i in restored.route) smallNet.code(i)],
      equals(['AAA', 'BAA', 'BBA']),
    );

    expect(game.fly('BBB').$1, isA<LongerOutcome>());
    expect(game.status, equals(GameStatus.playing));
    expect(game.longerArrivals, equals(1));

    expect(game.back(), equals(smallNet.indexOf('BBB')));
    expect(game.back(), equals(smallNet.indexOf('BBA')));
    expect(game.back(), equals(smallNet.indexOf('BAA')));
    expect(game.back(), isNull);

    expect(game.fly('ABA').$1, isA<FlewOutcome>());
    expect(game.fly('ABB').$1, isA<FlewOutcome>());
    expect(game.fly('BBB').$1, isA<WonOutcome>());
    expect(game.status, equals(GameStatus.won));
    expect(game.shareSummary(), contains('after 1 longer route'));
    expect(
      fitPlace('Saint-Jacques-de-la-Lande, Ille-et-Vilaine, FR', 14),
      equals('Saint-Jac…, FR'),
    );
  });
}
