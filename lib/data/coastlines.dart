import 'dart:math' as math;
import 'dart:typed_data';

/// A geographic bounding box `(lonMin, lonMax, latMin, latMax)` in degrees.
/// Notice `lonMin` and `lonMax` may extend past ±180° when a view crosses the antimeridian.
class MapBounds {
  const MapBounds({
    required this.lonMin,
    required this.lonMax,
    required this.latMin,
    required this.latMax,
  });

  final double lonMin;
  final double lonMax;
  final double latMin;
  final double latMax;

  double get lonSpan => lonMax - lonMin;
  double get latSpan => latMax - latMin;
  double get centerLon => (lonMin + lonMax) / 2.0;
  double get centerLat => (latMin + latMax) / 2.0;

  /// Width-to-height ratio this view draws undistorted at: a degree of
  /// longitude is cos(latitude) as long as a degree of latitude. Uses the
  /// same floor as [CoastlineData.mapBounds] so fitted views already match.
  double get aspect => lonSpan * _latScale(centerLat) / latSpan;

  /// This view reshaped to draw undistorted on a canvas of `aspect`
  /// (width / height), about the same center and covering the same area.
  /// The canvas draws whatever view it's given stretched to fill it, so a
  /// view that doesn't match its canvas's shape looks squished. Keeping the
  /// area (rather than one side) means resizing a window back and forth
  /// returns to the same view instead of drifting.
  MapBounds withAspect(double aspect) {
    final want = math.max(0.1, aspect);
    if ((this.aspect - want).abs() <= want * 1e-9) return this;
    final scale = _latScale(centerLat);
    final area = lonSpan * latSpan;
    final newLonSpan = math.sqrt(area * want / scale);
    final newLatSpan = area / newLonSpan;
    return MapBounds(
      lonMin: centerLon - newLonSpan / 2.0,
      lonMax: centerLon + newLonSpan / 2.0,
      latMin: centerLat - newLatSpan / 2.0,
      latMax: centerLat + newLatSpan / 2.0,
    );
  }

  static double _latScale(double lat) =>
      math.max(0.2, math.cos(lat * math.pi / 180.0));
}

/// `(lon, lat)` coordinate in degrees for canvas geometry.
class LonLat {
  const LonLat(this.lon, this.lat);
  final double lon;
  final double lat;
}

/// `(lat, lon)` coordinate in degrees as stored on airports.
class LatLon {
  const LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// Clipped line segment `((ax, ay), (bx, by))` in `(lon, lat)` degrees.
class ClippedSegment {
  const ClippedSegment(this.ax, this.ay, this.bx, this.by);
  final double ax;
  final double ay;
  final double bx;
  final double by;
}

/// One coastline polyline from `coastlines.bin`, with its precomputed bounding box
/// so polylines outside the current map view can be skipped in O(1).
class Coastline {
  const Coastline({
    required this.xs,
    required this.ys,
    required this.perDegree,
    required this.bbox,
  });

  final Int32List xs;
  final Int32List ys;
  final double perDegree;
  final MapBounds bbox;

  int get length => xs.length;

  double lonAt(int index) => xs[index] / perDegree;
  double latAt(int index) => ys[index] / perDegree;
}

/// Natural Earth coastlines at three scales (1:110m, 1:50m, 1:10m), plus map geometry helpers
/// ported from `jotto-cli/src/flights/coast.rs` and `jotto-cli/src/flights/tui.rs`.
class CoastlineData {
  const CoastlineData(this.scales);

  final List<List<Coastline>> scales;

  static const double _coarseAbove = 0.3;
  static const double _middleAbove = 0.05;

  static const double mapPadding = 0.2;
  static const double minLatSpan = 4.0;
  static const double minViewLat = 0.5;
  static const double maxViewLat = 200.0;
  static const double _curveStep = 1.0;

  /// Picks the coastline scale for `latSpan` degrees and `rows` terminal rows (`coast::for_view`).
  List<Coastline> forTerminalView(double latSpan, int rows) {
    final perDot = latSpan / (math.max(1, rows) * 4.0);
    final int i;
    if (perDot > _coarseAbove) {
      i = 0;
    } else if (perDot > _middleAbove) {
      i = 1;
    } else {
      i = 2;
    }
    return scales[math.min(i, scales.length - 1)];
  }

  /// Picks the coastline scale for a high-DPI canvas showing `latSpan` degrees.
  List<Coastline> forCanvasView(double latSpan) {
    final int i;
    if (latSpan > 75.0) {
      i = 0;
    } else if (latSpan > 14.0) {
      i = 1;
    } else {
      i = 2;
    }
    return scales[math.min(i, scales.length - 1)];
  }

  /// Parses `coastlines.bin` (`CST1` format).
  static CoastlineData parse(Uint8List bytes) {
    if (bytes.length < 5 ||
        bytes[0] != 0x43 || // 'C'
        bytes[1] != 0x53 || // 'S'
        bytes[2] != 0x54 || // 'T'
        bytes[3] != 0x31) {
      // '1'
      throw const FormatException('coastlines.bin has the wrong magic number');
    }

    final bd = ByteData.sublistView(bytes);
    final scaleCount = bytes[4];
    var pos = 5;

    final scales = <List<Coastline>>[];
    for (var s = 0; s < scaleCount; s++) {
      final perDegree = bd.getUint32(pos, Endian.little).toDouble();
      pos += 4;
      final lineCount = bd.getUint32(pos, Endian.little);
      pos += 4;

      final lines = <Coastline>[];
      for (var l = 0; l < lineCount; l++) {
        final n = bd.getUint32(pos, Endian.little);
        pos += 4;
        var x = bd.getInt32(pos, Endian.little);
        pos += 4;
        var y = bd.getInt32(pos, Endian.little);
        pos += 4;

        final xs = Int32List(n);
        final ys = Int32List(n);
        xs[0] = x;
        ys[0] = y;
        var xMin = x;
        var xMax = x;
        var yMin = y;
        var yMax = y;

        for (var p = 1; p < n; p++) {
          x += bd.getInt16(pos, Endian.little);
          pos += 2;
          y += bd.getInt16(pos, Endian.little);
          pos += 2;
          xs[p] = x;
          ys[p] = y;
          if (x < xMin) xMin = x;
          if (x > xMax) xMax = x;
          if (y < yMin) yMin = y;
          if (y > yMax) yMax = y;
        }

        lines.add(
          Coastline(
            xs: xs,
            ys: ys,
            perDegree: perDegree,
            bbox: MapBounds(
              lonMin: xMin / perDegree,
              lonMax: xMax / perDegree,
              latMin: yMin / perDegree,
              latMax: yMax / perDegree,
            ),
          ),
        );
      }
      scales.add(lines);
    }
    return CoastlineData(scales);
  }

  /// Moves a longitude by whole 360° turns to within 180° of `centre`.
  static double wrapLon(double lon, double centre) {
    return lon - ((lon - centre) / 360.0).roundToDouble() * 360.0;
  }

  /// Whole 360° turns to shift the world by so every copy visible in `bounds` is drawn.
  static List<double> turns(MapBounds bounds) {
    final first = ((bounds.lonMin - 360.0) / 360.0).ceil();
    final last = ((bounds.lonMax + 360.0) / 360.0).floor();
    if (first > last) return const [];
    return [for (var k = first; k <= last; k++) k * 360.0];
  }

  /// Clips the segment `(ax, ay) -> (bx, by)` to `bounds` using Liang-Barsky clipping.
  static ClippedSegment? clip(
    double ax,
    double ay,
    double bx,
    double by,
    MapBounds bounds,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    var t0 = 0.0;
    var t1 = 1.0;

    final p0 = -dx;
    final q0 = ax - bounds.lonMin;
    if (p0 == 0.0) {
      if (q0 < 0.0) return null;
    } else {
      final t = q0 / p0;
      if (p0 < 0.0) {
        t0 = math.max(t0, t);
      } else {
        t1 = math.min(t1, t);
      }
    }

    final p1 = dx;
    final q1 = bounds.lonMax - ax;
    if (p1 == 0.0) {
      if (q1 < 0.0) return null;
    } else {
      final t = q1 / p1;
      if (p1 < 0.0) {
        t0 = math.max(t0, t);
      } else {
        t1 = math.min(t1, t);
      }
    }

    final p2 = -dy;
    final q2 = ay - bounds.latMin;
    if (p2 == 0.0) {
      if (q2 < 0.0) return null;
    } else {
      final t = q2 / p2;
      if (p2 < 0.0) {
        t0 = math.max(t0, t);
      } else {
        t1 = math.min(t1, t);
      }
    }

    final p3 = dy;
    final q3 = bounds.latMax - ay;
    if (p3 == 0.0) {
      if (q3 < 0.0) return null;
    } else {
      final t = q3 / p3;
      if (p3 < 0.0) {
        t0 = math.max(t0, t);
      } else {
        t1 = math.min(t1, t);
      }
    }

    if (t0 <= t1) {
      return ClippedSegment(
        ax + t0 * dx,
        ay + t0 * dy,
        ax + t1 * dx,
        ay + t1 * dy,
      );
    }
    return null;
  }

  /// Points `(lon, lat)` a flight leg from `a` to `b` is drawn through:
  /// straight (2 points) or spherical great-circle interpolation at 1° steps.
  static List<LonLat> legPoints(LonLat a, LonLat b, bool curved) {
    final straight = <LonLat>[a, LonLat(wrapLon(b.lon, a.lon), b.lat)];
    if (!curved) return straight;

    List<double> unit(LonLat pt) {
      final lon = pt.lon * math.pi / 180.0;
      final lat = pt.lat * math.pi / 180.0;
      return [
        math.cos(lat) * math.cos(lon),
        math.cos(lat) * math.sin(lon),
        math.sin(lat),
      ];
    }

    final p = unit(a);
    final q = unit(b);
    final dot = (p[0] * q[0] + p[1] * q[1] + p[2] * q[2]).clamp(-1.0, 1.0);
    final angle = math.acos(dot);

    if (angle < 1e-9 || (math.pi - angle) < 1e-9) {
      return straight;
    }

    final steps = ((angle * 180.0 / math.pi) / _curveStep).ceil();
    final sinAngle = math.sin(angle);
    final points = <LonLat>[a];

    for (var k = 1; k <= steps; k++) {
      final t = k / steps;
      final wa = math.sin((1.0 - t) * angle) / sinAngle;
      final wb = math.sin(t * angle) / sinAngle;
      final rx = wa * p[0] + wb * q[0];
      final ry = wa * p[1] + wb * q[1];
      final rz = (wa * p[2] + wb * q[2]).clamp(-1.0, 1.0);
      final lat = math.asin(rz) * 180.0 / math.pi;
      final prevLon = points.last.lon;
      final lon = wrapLon(math.atan2(ry, rx) * 180.0 / math.pi, prevLon);
      points.add(LonLat(lon, lat));
    }
    return points;
  }

  /// Computes map bounds `(lonMin, lonMax, latMin, latMax)` fitting `points` with padding,
  /// choosing the narrowest longitude arc (even across ±180°) and widening to match `aspectRatio`.
  static MapBounds mapBounds(List<LatLon> points, double aspectRatio) {
    if (points.isEmpty) {
      return const MapBounds(
        lonMin: -180.0,
        lonMax: 180.0,
        latMin: -70.0,
        latMax: 70.0,
      );
    }

    var latMin = double.infinity;
    var latMax = double.negativeInfinity;
    final lons = <double>[];
    for (final p in points) {
      if (p.lat < latMin) latMin = p.lat;
      if (p.lat > latMax) latMax = p.lat;
      lons.add(p.lon);
    }
    lons.sort();

    var bestGap = lons.first + 360.0 - lons.last;
    var bestStart = lons.first;
    for (var i = 0; i < lons.length - 1; i++) {
      final gap = lons[i + 1] - lons[i];
      if (gap > bestGap) {
        bestGap = gap;
        bestStart = lons[i + 1];
      }
    }
    final lonMin = bestStart;
    final lonMax = bestStart + 360.0 - bestGap;

    final midLat = (latMin + latMax) / 2.0;
    final midLon = (lonMin + lonMax) / 2.0;
    final latScale = math.max(0.2, math.cos(midLat * math.pi / 180.0));
    var latSpan =
        math.max(minLatSpan, (latMax - latMin) * (1.0 + 2.0 * mapPadding));
    var lonSpan = (lonMax - lonMin) * (1.0 + 2.0 * mapPadding);

    final want = math.max(0.1, aspectRatio);
    if (lonSpan * latScale / latSpan < want) {
      lonSpan = want * latSpan / latScale;
    } else {
      latSpan = lonSpan * latScale / want;
    }

    return MapBounds(
      lonMin: midLon - lonSpan / 2.0,
      lonMax: midLon + lonSpan / 2.0,
      latMin: midLat - latSpan / 2.0,
      latMax: midLat + latSpan / 2.0,
    );
  }
}
