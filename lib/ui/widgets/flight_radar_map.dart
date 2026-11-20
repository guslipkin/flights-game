import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/coastlines.dart';
import '../../data/network.dart';
import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';

class _AirportNodeSpec {
  const _AirportNodeSpec({
    required this.airportIdx,
    required this.code,
    required this.textColor,
    required this.dotColor,
    this.badgeBg,
    this.isCurrent = false,
    this.isDestination = false,
    this.isSelectedOption = false,
  });

  final int airportIdx;
  final String code;
  final Color textColor;
  final Color dotColor;
  final Color? badgeBg;
  final bool isCurrent;
  final bool isDestination;
  final bool isSelectedOption;
}

class _ScreenAirportHit {
  const _ScreenAirportHit(this.airportIdx, this.x, this.y);
  final int airportIdx;
  final double x;
  final double y;
}

class FlightRadarMap extends StatefulWidget {
  const FlightRadarMap({
    super.key,
    required this.controller,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  final FlightsController controller;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;

  @override
  State<FlightRadarMap> createState() => _FlightRadarMapState();
}

class _FlightRadarMapState extends State<FlightRadarMap> {
  final List<_ScreenAirportHit> _hitTargets = <_ScreenAirportHit>[];
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  Offset? _doubleTapPosition;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final game = ctrl.game;
    final net = ctrl.currentNetwork;
    final options = ctrl.options;
    final selectedOpt = (ctrl.selectedOptionIndex != null &&
            ctrl.selectedOptionIndex! >= 0 &&
            ctrl.selectedOptionIndex! < options.length)
        ? options[ctrl.selectedOptionIndex!]
        : null;
    final showVia = game.rules.showsConnections();

    List<int> pathOf(int a, List<int> via, int b) {
      return <int>[a, if (showVia) ...via, b];
    }

    List<List<int>> pathsOf(List<int> stops, List<Ticket> legs) {
      final list = <List<int>>[];
      final count = math.min(stops.length - 1, legs.length);
      for (var i = 0; i < count; i++) {
        list.add(pathOf(stops[i], legs[i].via, stops[i + 1]));
      }
      return list;
    }

    final flownPaths = pathsOf(game.route, game.legs);
    final bestPaths = game.status == GameStatus.givenUp
        ? pathsOf(game.bestRoute, game.bestLegs)
        : const <List<int>>[];

    final hop = ctrl.selectedHop;
    final previewPaths = hop != null
        ? <List<int>>[pathOf(hop.from, hop.ticket.via, hop.to)]
        : selectedOpt != null
            ? <List<int>>[
                pathOf(
                    game.current, selectedOpt.connections, selectedOpt.airport),
              ]
            : const <List<int>>[];

    final shown = <int>{
      game.origin,
      game.destination,
      game.current,
      for (final p in flownPaths) ...p,
      for (final p in bestPaths) ...p,
      for (final p in previewPaths) ...p,
      for (final o in options) o.airport,
    };

    final fittingPoints = <LatLon>[for (final idx in shown) net.coords(idx)];
    if (game.curves) {
      LonLat xy(int i) {
        final c = net.coords(i);
        return LonLat(c.lon, c.lat);
      }

      for (final path in [...flownPaths, ...bestPaths, ...previewPaths]) {
        for (var i = 0; i < path.length - 1; i++) {
          final curve =
              CoastlineData.legPoints(xy(path[i]), xy(path[i + 1]), true);
          for (final pt in curve) {
            fittingPoints
                .add(LatLon(pt.lat, CoastlineData.wrapLon(pt.lon, 0.0)));
          }
        }
      }
    }

    final labelled = <int>{};
    final nodeSpecs = <_AirportNodeSpec>[];

    void addLabel({
      required int idx,
      required Color textColor,
      required Color dotColor,
      Color? badgeBg,
      bool isCurrent = false,
      bool isDestination = false,
      bool isSelectedOption = false,
    }) {
      if (labelled.add(idx)) {
        final baseCode = net.code(idx);
        final displayCode = idx == game.destination ? '$baseCode★' : baseCode;
        nodeSpecs.add(
          _AirportNodeSpec(
            airportIdx: idx,
            code: displayCode,
            textColor: textColor,
            dotColor: dotColor,
            badgeBg: badgeBg,
            isCurrent: isCurrent,
            isDestination: isDestination,
            isSelectedOption: isSelectedOption,
          ),
        );
      }
    }

    if (hop != null) {
      addLabel(
        idx: hop.to,
        textColor: FlightDeckColors.onAccent,
        dotColor: FlightDeckColors.warningOrange,
        badgeBg: FlightDeckColors.warningOrange,
        isSelectedOption: true,
      );
      addLabel(
        idx: hop.from,
        textColor: FlightDeckColors.warningOrange,
        dotColor: FlightDeckColors.warningOrange,
      );
    }

    addLabel(
      idx: game.destination,
      textColor: FlightDeckColors.destinationPurple,
      dotColor: FlightDeckColors.destinationPurple,
      badgeBg: selectedOpt?.airport == game.destination
          ? FlightDeckColors.warningOrange
          : null,
      isDestination: true,
      isSelectedOption: selectedOpt?.airport == game.destination,
    );

    if (game.status == GameStatus.playing) {
      addLabel(
        idx: game.current,
        textColor: FlightDeckColors.positiveGreen,
        dotColor: FlightDeckColors.positiveGreen,
        isCurrent: true,
      );
    }

    addLabel(
      idx: game.origin,
      textColor: FlightDeckColors.textPrimary,
      dotColor: FlightDeckColors.textPrimary,
    );

    if (selectedOpt != null) {
      addLabel(
        idx: selectedOpt.airport,
        textColor: FlightDeckColors.onAccent,
        dotColor: FlightDeckColors.warningOrange,
        badgeBg: FlightDeckColors.warningOrange,
        isSelectedOption: true,
      );
    }

    for (final opt in options) {
      addLabel(
        idx: opt.airport,
        textColor: FlightDeckColors.warningOrange,
        dotColor: FlightDeckColors.warningOrange,
      );
    }

    for (final idx in game.route) {
      addLabel(
        idx: idx,
        textColor: FlightDeckColors.accentSkyBlue,
        dotColor: FlightDeckColors.accentSkyBlue,
      );
    }

    if (game.status == GameStatus.givenUp) {
      for (final idx in game.bestRoute.reversed) {
        addLabel(
          idx: idx,
          textColor: FlightDeckColors.positiveGreen,
          dotColor: FlightDeckColors.positiveGreen,
        );
      }
    }

    for (final path in [...flownPaths, ...bestPaths, ...previewPaths]) {
      for (var i = 1; i < path.length - 1; i++) {
        addLabel(
          idx: path[i],
          textColor: FlightDeckColors.textMuted,
          dotColor: FlightDeckColors.textSecondary,
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: FlightDeckColors.radarBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = math.max(1.0, constraints.maxWidth);
          final h = math.max(1.0, constraints.maxHeight);
          final fitted = CoastlineData.mapBounds(fittingPoints, w / h);
          ctrl.syncViewport(fitted, w / h);
          final bounds = ctrl.userMapBounds ?? fitted;

          return Stack(
            children: [
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final factor =
                        event.scrollDelta.dy > 0 ? 1.15 : (1.0 / 1.15);
                    final fx = (event.localPosition.dx / w).clamp(0.0, 1.0);
                    final fy = (event.localPosition.dy / h).clamp(0.0, 1.0);
                    ctrl.zoomMap(factor, focusFracX: fx, focusFracY: fy);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _lastFocalPoint = details.localFocalPoint;
                    _lastScale = 1.0;
                  },
                  onScaleUpdate: (details) {
                    final prevFocal =
                        _lastFocalPoint ?? details.localFocalPoint;
                    final panDx = details.localFocalPoint.dx - prevFocal.dx;
                    final panDy = details.localFocalPoint.dy - prevFocal.dy;
                    _lastFocalPoint = details.localFocalPoint;

                    final scaleDelta = details.scale / _lastScale;
                    _lastScale = details.scale;
                    final zoomFactor =
                        scaleDelta > 0.0 ? (1.0 / scaleDelta) : 1.0;

                    ctrl.transformMap(
                      zoomFactor: zoomFactor,
                      panFracX: panDx / w,
                      panFracY: panDy / h,
                      focusFracX:
                          (details.localFocalPoint.dx / w).clamp(0.0, 1.0),
                      focusFracY:
                          (details.localFocalPoint.dy / h).clamp(0.0, 1.0),
                    );
                  },
                  onTapUp: (details) {
                    final tap = details.localPosition;
                    _ScreenAirportHit? nearest;
                    var bestDist = 28.0;
                    for (final target in _hitTargets) {
                      final dx = target.x - tap.dx;
                      final dy = target.y - tap.dy;
                      final d = math.sqrt(dx * dx + dy * dy);
                      if (d <= bestDist) {
                        bestDist = d;
                        nearest = target;
                      }
                    }
                    if (nearest != null) {
                      ctrl.onMapAirportTapped(
                        nearest.airportIdx,
                        kind: details.kind,
                      );
                    }
                  },
                  onDoubleTapDown: (details) {
                    _doubleTapPosition = details.localPosition;
                  },
                  onDoubleTap: () {
                    final pos = _doubleTapPosition ?? Offset(w / 2, h / 2);
                    ctrl.zoomMap(
                      1.0 / 1.5,
                      focusFracX: (pos.dx / w).clamp(0.0, 1.0),
                      focusFracY: (pos.dy / h).clamp(0.0, 1.0),
                    );
                  },
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _RadarMapPainter(
                      bounds: bounds,
                      coastlines: ctrl.coastlines,
                      network: net,
                      flownPaths: flownPaths,
                      bestPaths: bestPaths,
                      previewPaths: previewPaths,
                      nodeSpecs: nodeSpecs,
                      curved: game.curves,
                      status: game.status,
                      hitTargets: _hitTargets,
                    ),
                  ),
                ),
              ),

              // Top-left map legend pill
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlightDeckColors.surfaceCard.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: FlightDeckColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(
                        color: FlightDeckColors.positiveGreen,
                        label: game.currentCode,
                      ),
                      const SizedBox(width: 10),
                      _LegendDot(
                        color: FlightDeckColors.destinationPurple,
                        label: '${game.endCode}★',
                      ),
                      const SizedBox(width: 10),
                      if (game.status == GameStatus.givenUp) ...[
                        _LegendDot(
                          color: FlightDeckColors.accentSkyBlue,
                          label: 'Yours',
                        ),
                        const SizedBox(width: 10),
                        _LegendDot(
                          color: FlightDeckColors.positiveGreen,
                          label: 'Shortest',
                        ),
                      ] else
                        _LegendDot(
                          color: FlightDeckColors.warningOrange,
                          label: 'Options',
                        ),
                    ],
                  ),
                ),
              ),

              // Top-right Full Screen Toggle Button
              Positioned(
                top: 8,
                right: 8,
                child: _RadarHudButton(
                  text: widget.isFullScreen ? 'Exit Full' : 'Full',
                  accent: widget.isFullScreen,
                  onTap: widget.onToggleFullScreen,
                ),
              ),

              // Bottom-right Zoom & Fit HUD Buttons
              Positioned(
                bottom: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ctrl.userMapBounds != null) ...[
                      _RadarHudButton(
                        text: 'Fit',
                        accent: true,
                        onTap: ctrl.fitMap,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RadarHudButton(
                          text: '−',
                          onTap: () => ctrl.zoomMap(1.5),
                        ),
                        const SizedBox(width: 4),
                        _RadarHudButton(
                          text: '+',
                          onTap: () => ctrl.zoomMap(1.0 / 1.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  _RadarMapPainter({
    required this.bounds,
    required this.coastlines,
    required this.network,
    required this.flownPaths,
    required this.bestPaths,
    required this.previewPaths,
    required this.nodeSpecs,
    required this.curved,
    required this.status,
    required this.hitTargets,
  });

  final MapBounds bounds;
  final CoastlineData coastlines;
  final Network network;
  final List<List<int>> flownPaths;
  final List<List<int>> bestPaths;
  final List<List<int>> previewPaths;
  final List<_AirportNodeSpec> nodeSpecs;
  final bool curved;
  final GameStatus status;
  final List<_ScreenAirportHit> hitTargets;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w < 8 || h < 8) return;

    Offset toScreen(double lon, double lat) {
      final sx = (lon - bounds.lonMin) / bounds.lonSpan * w;
      final sy = (bounds.latMax - lat) / bounds.latSpan * h;
      return Offset(sx, sy);
    }

    // 1. Subtle radar graticule grid (every 30 degrees)
    final gridPaint = Paint()
      ..color = FlightDeckColors.radarGrid
      ..strokeWidth = 1.0;

    const step = 30.0;
    var lon = (bounds.lonMin / step).ceil() * step;
    final lastLon = (bounds.lonMax / step).floor() * step;
    while (lon <= lastLon) {
      canvas.drawLine(
        toScreen(lon, bounds.latMax),
        toScreen(lon, bounds.latMin),
        gridPaint,
      );
      lon += step;
    }

    var lat = (bounds.latMin / step).ceil() * step;
    final lastLat = (bounds.latMax / step).floor() * step;
    while (lat <= lastLat) {
      if (lat >= -90.0 && lat <= 90.0) {
        canvas.drawLine(
          toScreen(bounds.lonMin, lat),
          toScreen(bounds.lonMax, lat),
          gridPaint,
        );
      }
      lat += step;
    }

    // 2. Natural Earth vector coastlines
    final coastPaint = Paint()
      ..color = FlightDeckColors.coastlineVector
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;

    final activeCoastlines = coastlines.forCanvasView(bounds.latSpan);
    final turns = CoastlineData.turns(bounds);
    for (final turn in turns) {
      for (final line in activeCoastlines) {
        final bbox = line.bbox;
        if (bbox.lonMax + turn < bounds.lonMin ||
            bbox.lonMin + turn > bounds.lonMax ||
            bbox.latMax < bounds.latMin ||
            bbox.latMin > bounds.latMax) {
          continue;
        }
        final count = line.length;
        for (var i = 0; i < count - 1; i++) {
          final seg = CoastlineData.clip(
            line.lonAt(i) + turn,
            line.latAt(i),
            line.lonAt(i + 1) + turn,
            line.latAt(i + 1),
            bounds,
          );
          if (seg != null) {
            canvas.drawLine(
              toScreen(seg.ax, seg.ay),
              toScreen(seg.bx, seg.by),
              coastPaint,
            );
          }
        }
      }
    }

    // 3. Flight paths (Flown in Sky Blue, Best in Green on GiveUp, Preview in Orange)
    void drawFlightPaths(
      List<List<int>> paths,
      Color color,
      double strokeWidth, {
      bool dashed = false,
    }) {
      if (paths.isEmpty) return;
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = strokeWidth * 2.4
        ..strokeCap = StrokeCap.round;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      for (final path in paths) {
        for (var i = 0; i < path.length - 1; i++) {
          final ca = network.coords(path[i]);
          final cb = network.coords(path[i + 1]);
          final legPts = CoastlineData.legPoints(
            LonLat(ca.lon, ca.lat),
            LonLat(cb.lon, cb.lat),
            curved,
          );
          for (final turn in turns) {
            for (var j = 0; j < legPts.length - 1; j++) {
              final p0 = legPts[j];
              final p1 = legPts[j + 1];
              final seg = CoastlineData.clip(
                p0.lon + turn,
                p0.lat,
                p1.lon + turn,
                p1.lat,
                bounds,
              );
              if (seg != null) {
                final startOff = toScreen(seg.ax, seg.ay);
                final endOff = toScreen(seg.bx, seg.by);
                canvas.drawLine(startOff, endOff, glowPaint);
                if (!dashed || j % 2 == 0 || legPts.length <= 4) {
                  canvas.drawLine(startOff, endOff, linePaint);
                }
              }
            }
          }
        }
      }
    }

    drawFlightPaths(flownPaths, FlightDeckColors.accentSkyBlue, 2.3);
    if (status == GameStatus.givenUp) {
      drawFlightPaths(bestPaths, FlightDeckColors.positiveGreen, 2.5);
    }
    drawFlightPaths(
      previewPaths,
      FlightDeckColors.warningOrange,
      2.6,
      dashed: status == GameStatus.playing,
    );

    // 4. Airport dots and non-overlapping monospace code labels
    hitTargets.clear();
    final occupiedRects = <Rect>[];
    final centerLon = bounds.centerLon;
    const dotRadius = 3.8;
    const labelPadH = 4.0;
    const labelPadV = 2.0;

    for (final spec in nodeSpecs) {
      final coord = network.coords(spec.airportIdx);
      final lon = CoastlineData.wrapLon(coord.lon, centerLon);
      final lat = coord.lat;
      if (lon < bounds.lonMin ||
          lon > bounds.lonMax ||
          lat < bounds.latMin ||
          lat > bounds.latMax) {
        continue;
      }
      final pt = toScreen(lon, lat);
      hitTargets.add(_ScreenAirportHit(spec.airportIdx, pt.dx, pt.dy));

      final dotPaint = Paint()..color = spec.dotColor;
      if (spec.isCurrent || spec.isDestination || spec.isSelectedOption) {
        canvas.drawCircle(
          pt,
          dotRadius * 2.2,
          Paint()..color = spec.dotColor.withValues(alpha: 0.28),
        );
        canvas.drawCircle(pt, dotRadius * 1.25, dotPaint);
      } else {
        canvas.drawCircle(pt, dotRadius, dotPaint);
      }

      final dotBox = Rect.fromLTRB(
        pt.dx - dotRadius - 2,
        pt.dy - dotRadius - 2,
        pt.dx + dotRadius + 2,
        pt.dy + dotRadius + 2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: spec.code,
          style: TextStyle(
            fontFamily: FlightDeckColors.monospaceFontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            color: spec.badgeBg != null
                ? FlightDeckColors.onAccent
                : spec.textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxW = tp.width + labelPadH * 2;
      final boxH = tp.height + labelPadV * 2;
      const gap = dotRadius + 4.0;

      final candidates = <Offset>[
        Offset(pt.dx + gap, pt.dy - boxH / 2),
        Offset(pt.dx - gap - boxW, pt.dy - boxH / 2),
        Offset(pt.dx - boxW / 2, pt.dy - gap - boxH),
        Offset(pt.dx - boxW / 2, pt.dy + gap),
        Offset(pt.dx + gap, pt.dy - gap - boxH),
        Offset(pt.dx - gap - boxW, pt.dy - gap - boxH),
        Offset(pt.dx + gap, pt.dy + gap),
        Offset(pt.dx - gap - boxW, pt.dy + gap),
      ];

      Rect? chosenRect;
      for (final cand in candidates) {
        final rect = Rect.fromLTWH(cand.dx, cand.dy, boxW, boxH);
        if (rect.left < 2 ||
            rect.right > w - 2 ||
            rect.top < 2 ||
            rect.bottom > h - 2) {
          continue;
        }
        final overlaps = occupiedRects.any((r) => r.overlaps(rect));
        if (!overlaps) {
          chosenRect = rect;
          break;
        }
      }

      occupiedRects.add(dotBox);

      if (chosenRect != null) {
        occupiedRects.add(chosenRect);
        final bgPaint = Paint()
          ..color = spec.badgeBg ??
              FlightDeckColors.radarBackground.withValues(alpha: 0.84);
        canvas.drawRRect(
          RRect.fromRectAndRadius(chosenRect, const Radius.circular(4)),
          bgPaint,
        );
        tp.paint(
          canvas,
          Offset(chosenRect.left + labelPadH, chosenRect.top + labelPadV),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarMapPainter oldDelegate) => true;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: FlightDeckColors.monospaceFontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: FlightDeckColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RadarHudButton extends StatelessWidget {
  const _RadarHudButton({
    required this.text,
    required this.onTap,
    this.accent = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        accent ? FlightDeckColors.accentSkyBlue : FlightDeckColors.borderAccent;
    final textColor =
        accent ? FlightDeckColors.accentSkyBlue : FlightDeckColors.textPrimary;

    return Material(
      color: FlightDeckColors.surfaceCard.withValues(alpha: 0.90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: FlightDeckColors.monospaceFontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
