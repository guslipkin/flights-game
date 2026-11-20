import 'dart:convert';
import 'dart:io';

import 'package:flights/data/coastlines.dart';
import 'package:flights/data/flights_repository.dart';
import 'package:flights/game/flights_game.dart';
import 'package:flights/ui/flights_controller.dart';
import 'package:flights/ui/flights_screen.dart';
import 'package:flights/ui/theme/flight_deck_theme.dart';
import 'package:flights/util/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String release(String tag) => jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/guslipkin/flights-game/releases/tag/$tag',
    });

void main() {
  group('isNewer', () {
    test('compares dotted numbers, not text', () {
      expect(UpdateChecker.isNewer('1.10.0', '1.9.2'), isTrue);
      expect(UpdateChecker.isNewer('0.2.0', '0.1.9'), isTrue);
      expect(UpdateChecker.isNewer('2', '1.9.9'), isTrue);
      expect(UpdateChecker.isNewer('1.2.3', '1.2.3'), isFalse);
      expect(UpdateChecker.isNewer('1.2', '1.2.0'), isFalse);
      expect(UpdateChecker.isNewer('0.0.1', '0.1.0'), isFalse);
    });

    test('ignores build and pre-release suffixes', () {
      expect(UpdateChecker.isNewer('1.2.4-beta', '1.2.3'), isTrue);
      expect(UpdateChecker.isNewer('1.2.3', '1.2.3+42'), isFalse);
    });

    test('a version that is not numbers is never newer', () {
      expect(UpdateChecker.isNewer('latest', '0.1.0'), isFalse);
      expect(UpdateChecker.isNewer('1.2.3.4', '0.1.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0.0', 'dev'), isFalse);
    });
  });

  group('parse', () {
    test('a newer release is an update, without the tag\'s v', () {
      final u = UpdateChecker.parse(release('v0.2.0'), '0.1.0');
      expect(u?.version, '0.2.0');
      expect(u?.url, endsWith('/releases/tag/v0.2.0'));
    });

    test('the same or an older release is not', () {
      expect(UpdateChecker.parse(release('v0.1.0'), '0.1.0'), isNull);
      expect(UpdateChecker.parse(release('v0.0.1'), '0.1.0'), isNull);
    });

    test('an unexpected reply is not', () {
      expect(UpdateChecker.parse('not json', '0.1.0'), isNull);
      expect(UpdateChecker.parse('[]', '0.1.0'), isNull);
      expect(UpdateChecker.parse('{"message":"Not Found"}', '0.1.0'), isNull);
    });
  });

  group('check', () {
    // The widget test below turns on Flutter's test binding, which fakes every
    // HTTP request with a 400. These tests talk to a real local server, so
    // they put the real HttpClient back for their duration.
    HttpOverrides? saved;
    setUp(() {
      saved = HttpOverrides.current;
      HttpOverrides.global = null;
    });
    tearDown(() => HttpOverrides.global = saved);

    test('finds a newer release from the server', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      String? userAgent;
      server.listen((req) {
        userAgent = req.headers.value(HttpHeaders.userAgentHeader);
        req.response
          ..write(release('v9.0.0'))
          ..close();
      });
      final u = await UpdateChecker.check(
        '0.1.0',
        source: Uri.parse('http://127.0.0.1:${server.port}/latest'),
      );
      expect(u?.version, '9.0.0');
      expect(userAgent, isNotEmpty);
    });

    test('an unreachable server is ignored', () async {
      // Bind and close a port, so nothing is listening there.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final u = await UpdateChecker.check(
        '0.1.0',
        source: Uri.parse('http://127.0.0.1:$port/latest'),
      );
      expect(u, isNull);
    });

    test('an error reply (rate limited, not found) is ignored', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        req.response
          ..statusCode = HttpStatus.forbidden
          ..write(release('v9.0.0'))
          ..close();
      });
      final u = await UpdateChecker.check(
        '0.1.0',
        source: Uri.parse('http://127.0.0.1:${server.port}/latest'),
      );
      expect(u, isNull);
    });
  });

  testWidgets('the banner links to the release and can be dismissed',
      (tester) async {
    String? opened;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('me.guslipkin.flights/platform'),
      (call) async {
        if (call.method == 'openUrl') {
          opened = (call.arguments as Map)['url'] as String;
        }
        return null;
      },
    );
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(MaterialApp(home: FlightsScreen(controller: ctrl)));
    expect(find.textContaining('is available'), findsNothing);

    ctrl.availableUpdate = UpdateChecker.parse(release('v0.2.0'), '0.1.0');
    ctrl.notifyListeners();
    await tester.pump();
    expect(find.text('Flights 0.2.0 is available'), findsOneWidget);

    await tester.tap(find.text('Get it'));
    await tester.pump();
    expect(opened, endsWith('/releases/tag/v0.2.0'));

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.textContaining('is available'), findsNothing);
    expect(ctrl.availableUpdate, isNull);
  });
}
