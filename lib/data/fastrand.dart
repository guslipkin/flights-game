/// Exact 64-bit Dart port of Rust's `fastrand 2.5.0` (`Rng(u64)` using WyRand v4.2 and Lemire's
/// divisionless `gen_mod_u64`), plus deterministic UTC daily helpers from `jotto-cli`.
///
/// Uses Dart `BigInt` for exact 64x64 -> 128-bit unsigned arithmetic so `Network.dailyPuzzle`
/// produces the exact same daily puzzle as `flights --daily` in `jotto-cli` on every UTC day.
class Fastrand {
  Fastrand([BigInt? seed]) : _state = (seed ?? _defaultSeed()) & _mask64;

  factory Fastrand.fromInt(int seed) =>
      Fastrand(BigInt.from(seed).toUnsigned(64));

  BigInt _state;

  BigInt get state => _state;

  static final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;
  static final BigInt _mask128 = (BigInt.one << 128) - BigInt.one;
  static final BigInt _two64 = BigInt.one << 64;

  static final BigInt _wyConst0 = BigInt.parse('2d358dccaa6c78a5', radix: 16);
  static final BigInt _wyConst1 = BigInt.parse('8bb84b93962eacc9', radix: 16);
  static final BigInt _goldenGamma =
      BigInt.parse('9E3779B97F4A7C15', radix: 16);

  /// Fixed UTC epoch day (2024-01-01 UTC = 19,723 days since 1970-01-01).
  static const int dailyEpochDay = 19723;

  /// Fixed seed for `flights` daily puzzles (`"FLIGHTS!"` = `0x464C494748545321`).
  static final BigInt dailySeed = BigInt.parse('464C494748545321', radix: 16);

  static BigInt _defaultSeed() {
    final nowMicros =
        BigInt.from(DateTime.now().microsecondsSinceEpoch).toUnsigned(64);
    final nowMillis =
        BigInt.from(DateTime.now().millisecondsSinceEpoch).toUnsigned(64);
    return (nowMicros ^ ((nowMillis * _goldenGamma) & _mask64)) & _mask64;
  }

  /// Generates a random unsigned 64-bit value as a `BigInt` in `0..2^64-1`.
  BigInt genU64() {
    final s = (_state + _wyConst0) & _mask64;
    _state = s;
    final t = (s * (s ^ _wyConst1)) & _mask128;
    return ((t & _mask64) ^ (t >> 64)) & _mask64;
  }

  /// Generates a random unsigned 64-bit integer in `0..n-1` using Lemire's method.
  BigInt genModU64(BigInt n) {
    assert(n > BigInt.zero && n <= _mask64);
    var r = genU64();
    var prod = r * n;
    var hi = prod >> 64;
    var lo = prod & _mask64;
    if (lo < n) {
      final negN = (_two64 - n) & _mask64;
      final t = negN % n;
      while (lo < t) {
        r = genU64();
        prod = r * n;
        hi = prod >> 64;
        lo = prod & _mask64;
      }
    }
    return hi;
  }

  /// Equivalent to `rng.usize(0..n)` on 64-bit targets.
  int usize(int n) {
    if (n <= 0) {
      throw ArgumentError.value(n, 'n', 'Empty range: 0..$n');
    }
    return genModU64(BigInt.from(n)).toInt();
  }

  /// Equivalent to `rng.shuffle(&mut slice)` in `fastrand 2.5.0`.
  void shuffle<T>(List<T> list) {
    for (var i = 1; i < list.length; i++) {
      final j = genModU64(BigInt.from(i + 1)).toInt();
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Deterministic daily RNG for `utcDay` (days since 1970-01-01).
  static Fastrand forDaily(int utcDay) {
    final day = utcDay > dailyEpochDay ? (utcDay - dailyEpochDay) : 0;
    final dayBig = BigInt.from(day).toUnsigned(64);
    final seed = (dailySeed ^ ((dayBig * _goldenGamma) & _mask64)) & _mask64;
    return Fastrand(seed);
  }

  /// Current UTC day number (days since 1970-01-01 00:00:00 UTC).
  static int currentUtcDays() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    return millis <= 0 ? 0 : (millis ~/ 86400000);
  }

  /// Converts days since 1970-01-01 UTC into `(year, month, day)` using
  /// Howard Hinnant's civil calendar algorithm (`dict::utc_ymd_from_days`).
  static (int, int, int) utcYmdFromDays(int daysSinceEpoch) {
    final z = daysSinceEpoch + 719468;
    final era = (z >= 0 ? z : z - 146096) ~/ 146097;
    final doe = z - era * 146097;
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final y = yoe + era * 400;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
    final mp = (5 * doy + 2) ~/ 153;
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    final year = m <= 2 ? y + 1 : y;
    return (year, m, d);
  }

  /// Formats a UTC day number (days since 1970-01-01) as `"YYYY-MM-DD"`.
  static String formatUtcDate(int daysSinceEpoch) {
    final (y, m, d) = utcYmdFromDays(daysSinceEpoch);
    final ys = y.toString().padLeft(4, '0');
    final ms = m.toString().padLeft(2, '0');
    final ds = d.toString().padLeft(2, '0');
    return '$ys-$ms-$ds';
  }
}
