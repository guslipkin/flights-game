import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A newer release than the running app, from GitHub.
class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.url});

  /// The release's version without the tag's `v` ("1.2.3").
  final String version;

  /// The release's page, where the builds are attached.
  final String url;
}

/// Asks GitHub whether a newer release than the running app is out.
///
/// It's a courtesy, never in the way: any failure (offline, GitHub down or
/// rate-limited, an unexpected reply) is treated as "no update", silently.
class UpdateChecker {
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/guslipkin/flights-game/releases/latest';

  // Short, so a slow or captive network gives up quickly. The check runs in
  // the background, so even the full wait never delays the game.
  static const Duration _timeout = Duration(seconds: 5);

  /// `source` is only for tests, to point the check at a local server.
  static Future<AvailableUpdate?> check(
    String currentVersion, {
    Uri? source,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request =
          await client.getUrl(source ?? Uri.parse(_latestReleaseUrl));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        // GitHub's API rejects requests without a User-Agent.
        ..set(HttpHeaders.userAgentHeader, 'Flights-app');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      return parse(body, currentVersion);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The update described by a `releases/latest` reply, if it's newer than
  /// `currentVersion`.
  static AvailableUpdate? parse(String body, String currentVersion) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final tag = json['tag_name'];
      final url = json['html_url'];
      if (tag is! String || url is! String) return null;
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!isNewer(latest, currentVersion)) return null;
      return AvailableUpdate(version: latest, url: url);
    } catch (_) {
      return null;
    }
  }

  /// Whether version `a` is later than `b`, comparing dotted numbers
  /// ("1.10.0" > "1.9.2"). Anything after `-` or `+` is ignored, and a
  /// version that isn't numbers is never newer, so a bad tag can't nag.
  static bool isNewer(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    if (pa == null || pb == null) return false;
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] > pb[i];
    }
    return false;
  }

  static List<int>? _parts(String version) {
    final core = version.trim().split(RegExp(r'[-+]')).first;
    final pieces = core.split('.');
    if (pieces.isEmpty || pieces.length > 3) return null;
    final numbers = <int>[];
    for (final p in pieces) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      numbers.add(n);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }
}
