import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/network.dart';
import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';
import 'keep_visible.dart';
import 'options_panel.dart';

sealed class _ExpandedRouteEntry {
  _ExpandedRouteEntry();
}

class _SectionTitleEntry extends _ExpandedRouteEntry {
  _SectionTitleEntry(this.text, this.color);
  final String text;
  final Color color;
}

class _StopRowEntry extends _ExpandedRouteEntry {
  _StopRowEntry({
    required this.primarySpan,
    required this.remark,
    required this.place,
    required this.globalStep,
  });

  final TextSpan primarySpan;
  final (String, Color)? remark;
  final String place;
  final int? globalStep;
}

class RoutePanel extends StatefulWidget {
  const RoutePanel({
    super.key,
    required this.controller,
    required this.alwaysExpanded,
    this.maxExpandedHeight = 200.0,
  });

  final FlightsController controller;
  final bool alwaysExpanded;
  final double maxExpandedHeight;

  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  final ScrollController _compactScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();
  int _lastRouteLength = -1;
  StreamSubscription<int>? _pageRequests;

  @override
  void initState() {
    super.initState();
    _pageRequests = widget.controller.routePageRequests.listen(_scrollPages);
  }

  /// Page Up/Down: scrolls whichever route list is showing by most of its
  /// height, so a line of context stays in view.
  void _scrollPages(int pages) {
    final sc = _expandedScrollController.hasClients
        ? _expandedScrollController
        : _compactScrollController;
    if (!sc.hasClients) return;
    final pos = sc.position;
    final target = (pos.pixels + pages * pos.viewportDimension * 0.85)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageRequests?.cancel();
    _compactScrollController.dispose();
    _expandedScrollController.dispose();
    super.dispose();
  }

  void _scheduleAutoScrollCompact() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_compactScrollController.hasClients) {
        final maxExt = _compactScrollController.position.maxScrollExtent;
        _compactScrollController.jumpTo(maxExt);
      }
    });
  }

  void _scheduleAutoScrollExpanded(GameStatus status) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_expandedScrollController.hasClients) return;
      if (status == GameStatus.playing) {
        _expandedScrollController.jumpTo(
          _expandedScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final game = ctrl.game;
    final net = ctrl.currentNetwork;
    final font = FlightDeckColors.monospaceFontFamily;

    final isExpanded = widget.alwaysExpanded ||
        ctrl.routeExpanded ||
        game.status != GameStatus.playing;

    if (game.route.length != _lastRouteLength) {
      _lastRouteLength = game.route.length;
      if (!isExpanded) {
        _scheduleAutoScrollCompact();
      } else {
        _scheduleAutoScrollExpanded(game.status);
      }
    }

    final distanceSuffix = game.distancesVisible()
        ? ': ${game.units.format(game.totalDistance())}'
        : '';
    final headerTitle = switch (game.status) {
      GameStatus.playing =>
        'ROUTE (${game.hops} hop${pluralS(game.hops)}$distanceSuffix)',
      GameStatus.won => 'YOU WON! ROUTE$distanceSuffix',
      GameStatus.givenUp => 'GAME OVER · ROUTES',
    };
    final headerColor = switch (game.status) {
      GameStatus.playing => FlightDeckColors.accentSkyBlue,
      GameStatus.won => FlightDeckColors.positiveGreen,
      GameStatus.givenUp => FlightDeckColors.warningOrange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      child: Column(
        mainAxisSize:
            widget.alwaysExpanded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (!widget.alwaysExpanded &&
                          game.status == GameStatus.playing)
                      ? ctrl.toggleRouteExpanded
                      : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.6,
                            color: headerColor,
                          ),
                        ),
                      ),
                      if (!widget.alwaysExpanded &&
                          game.status == GameStatus.playing) ...[
                        const SizedBox(width: 6),
                        Text(
                          isExpanded ? '▾' : '▴',
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 12,
                            color: FlightDeckColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (game.status == GameStatus.playing)
                    _GoBackButton(
                      enabled: game.hops > 0,
                      onTap: ctrl.goBack,
                    )
                  else ...[
                    if (ctrl.stepCount > 0) ...[
                      _SmallRouteButton(
                        text: 'Prev Hop',
                        onTap: () => ctrl.stepRouteHop(false),
                      ),
                      const SizedBox(width: 6),
                      _SmallRouteButton(
                        text: 'Next Hop',
                        onTap: () => ctrl.stepRouteHop(true),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _SmallRouteButton(
                      text: 'Share',
                      accentColor: FlightDeckColors.accentSkyBlue,
                      onTap: ctrl.shareResults,
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (!isExpanded)
            _buildCompactBreadcrumb(ctrl, game, net, font)
          else if (widget.alwaysExpanded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _buildExpandedList(ctrl, game, net, font),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _buildExpandedList(ctrl, game, net, font),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactBreadcrumb(
    FlightsController ctrl,
    FlightsGame game,
    Network net,
    String font,
  ) {
    final route = game.route;
    final tokenCount = route.length + (game.atDestination() ? 0 : 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ctrl.toggleRouteExpanded,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerRight,
            child: ListView.builder(
              controller: _compactScrollController,
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: tokenCount,
              itemBuilder: (context, index) {
                if (index < route.length) {
                  final idx = route[index];
                  final code = net.code(idx);
                  final isCurrent = idx == game.current;
                  final isDest = idx == game.destination;
                  final baseColor = isCurrent
                      ? FlightDeckColors.positiveGreen
                      : isDest
                          ? FlightDeckColors.destinationPurple
                          : FlightDeckColors.textPrimary;
                  int? changed;
                  if (index > 0) {
                    final prevCode = net.code(route[index - 1]);
                    for (var c = 0; c < 3; c++) {
                      if (prevCode.codeUnitAt(c) != code.codeUnitAt(c)) {
                        changed = c;
                        break;
                      }
                    }
                  }
                  return RichText(
                    text: TextSpan(
                      children: [
                        if (index > 0) ...[
                          TextSpan(
                            text: ' → ',
                            style: TextStyle(
                              fontFamily: font,
                              fontSize: 13,
                              color: FlightDeckColors.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: '$index.',
                            style: TextStyle(
                              fontFamily: font,
                              fontSize: 12,
                              color: FlightDeckColors.textSecondary,
                            ),
                          ),
                        ],
                        styledAirportCodeSpan(
                          code: code,
                          changedIndex: changed,
                          baseColor: baseColor,
                          fontSize: 13,
                          isDestination: isDest,
                        ),
                      ],
                    ),
                  );
                } else {
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: ' → … → ',
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 13,
                            color: FlightDeckColors.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: '${game.endCode}★',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FlightDeckColors.destinationPurple,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedList(
    FlightsController ctrl,
    FlightsGame game,
    Network net,
    String font,
  ) {
    final entries = _buildEntries(game, net, font);

    return ListView.separated(
      controller: _expandedScrollController,
      shrinkWrap: !widget.alwaysExpanded,
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 3),
      itemBuilder: (context, index) {
        final entry = entries[index];
        switch (entry) {
          case _SectionTitleEntry():
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 1),
              child: Text(
                entry.text,
                style: TextStyle(
                  fontFamily: font,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: entry.color,
                ),
              ),
            );
          case _StopRowEntry():
            final isPicked = game.status != GameStatus.playing &&
                entry.globalStep != null &&
                ctrl.routeStep == entry.globalStep;
            return KeepVisible(
              active: isPicked,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: (game.status != GameStatus.playing &&
                        entry.globalStep != null)
                    ? () => ctrl.selectRouteHop(entry.globalStep)
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPicked
                        ? FlightDeckColors.selectedRowBg
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPicked
                          ? FlightDeckColors.warningOrange
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(text: entry.primarySpan),
                      if (entry.remark != null || entry.place.isNotEmpty)
                        _StopSecondLine(
                          remark: entry.remark,
                          place: entry.place,
                          font: font,
                        ),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }

  List<_ExpandedRouteEntry> _buildEntries(
    FlightsGame game,
    Network net,
    String font,
  ) {
    final entries = <_ExpandedRouteEntry>[];

    void appendRouteStops({
      required List<int> route,
      required List<Ticket> legs,
      required int stepOffset,
      required Color Function(int stopPos, int airportIdx) codeColorForStop,
      required (String, Color)? Function(int stopPos) remarkForStop,
    }) {
      if (route.isEmpty) return;
      final startIdx = route[0];
      entries.add(
        _StopRowEntry(
          primarySpan: TextSpan(
            children: [
              TextSpan(
                text: '    ${net.code(startIdx)}',
                style: TextStyle(
                  fontFamily: font,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: codeColorForStop(0, startIdx),
                ),
              ),
              TextSpan(
                text: '  start',
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 12.5,
                  color: FlightDeckColors.textSecondary,
                ),
              ),
            ],
          ),
          remark: remarkForStop(0),
          place: game.rules.showPlaces ? net.place(startIdx) : '',
          globalStep: null,
        ),
      );

      final hopCount = math.min(route.length - 1, legs.length);
      for (var n = 0; n < hopCount; n++) {
        final fromIdx = route[n];
        final toIdx = route[n + 1];
        final leg = legs[n];
        final fromCode = net.code(fromIdx);
        final toCode = net.code(toIdx);
        int? changed;
        for (var c = 0; c < 3; c++) {
          if (fromCode.codeUnitAt(c) != toCode.codeUnitAt(c)) {
            changed = c;
            break;
          }
        }

        final numLabel = (n + 1).toString().padLeft(2, ' ');
        entries.add(
          _StopRowEntry(
            primarySpan: TextSpan(
              children: [
                TextSpan(
                  text: '$numLabel. ',
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 12.5,
                    color: FlightDeckColors.textSecondary,
                  ),
                ),
                styledAirportCodeSpan(
                  code: toCode,
                  changedIndex: changed,
                  baseColor: codeColorForStop(n + 1, toIdx),
                  fontSize: 12.5,
                  isDestination: toIdx == game.destination,
                ),
                if (game.distancesVisible())
                  TextSpan(
                    text: '  ${game.units.format(leg.distance)}',
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 12.5,
                      color: FlightDeckColors.textSecondary,
                    ),
                  ),
                if (game.rules.showsConnections() && leg.via.isNotEmpty)
                  TextSpan(
                    text: ' via ${[
                      for (final i in leg.via) net.code(i)
                    ].join(', ')}',
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 11.5,
                      color: FlightDeckColors.textMuted,
                    ),
                  ),
              ],
            ),
            remark: remarkForStop(n + 1),
            place: game.rules.showPlaces ? net.place(toIdx) : '',
            globalStep: stepOffset + n,
          ),
        );
      }
    }

    if (game.status == GameStatus.givenUp) {
      final split = game.divergence();
      final yoursLeft = split < game.route.length;
      entries.add(
        _SectionTitleEntry(
          'Yours${game.distancesVisible() ? ': ${game.units.format(game.totalDistance())}' : ''}',
          FlightDeckColors.accentSkyBlue,
        ),
      );
      appendRouteStops(
        route: game.route,
        legs: game.legs,
        stepOffset: 0,
        codeColorForStop: (_, airportIdx) => airportIdx == game.destination
            ? FlightDeckColors.destinationPurple
            : FlightDeckColors.textPrimary,
        remarkForStop: (stopPos) => (yoursLeft && stopPos == split)
            ? (youLeftRemark, FlightDeckColors.warningOrange)
            : null,
      );

      entries.add(
        _SectionTitleEntry(
          'Shortest${game.distancesVisible() ? ': ${game.units.format(game.bestDistance)}' : ''}',
          FlightDeckColors.positiveGreen,
        ),
      );
      appendRouteStops(
        route: game.bestRoute,
        legs: game.bestLegs,
        stepOffset: game.legs.length,
        codeColorForStop: (stopPos, _) => stopPos < split
            ? FlightDeckColors.textSecondary
            : FlightDeckColors.positiveGreen,
        remarkForStop: (stopPos) => stopPos == split
            ? (
                yoursLeft ? wentHereRemark : nextHopRemark,
                FlightDeckColors.positiveGreen,
              )
            : null,
      );
    } else {
      appendRouteStops(
        route: game.route,
        legs: game.legs,
        stepOffset: 0,
        codeColorForStop: (_, airportIdx) {
          if (airportIdx == game.current && game.status == GameStatus.playing) {
            return FlightDeckColors.positiveGreen;
          }
          if (airportIdx == game.destination) {
            return FlightDeckColors.destinationPurple;
          }
          return FlightDeckColors.textPrimary;
        },
        remarkForStop: (_) => null,
      );

      if (!game.atDestination()) {
        entries.add(
          _StopRowEntry(
            primarySpan: TextSpan(
              children: [
                TextSpan(
                  text: '  … ',
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 12.5,
                    color: FlightDeckColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: game.endCode,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: FlightDeckColors.destinationPurple,
                  ),
                ),
                TextSpan(
                  text: '  destination',
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 12.5,
                    color: FlightDeckColors.textSecondary,
                  ),
                ),
              ],
            ),
            remark: null,
            place: game.rules.showPlaces ? net.place(game.destination) : '',
            globalStep: null,
          ),
        );
      }
    }

    return entries;
  }
}

class _StopSecondLine extends StatelessWidget {
  const _StopSecondLine({
    required this.remark,
    required this.place,
    required this.font,
  });

  final (String, Color)? remark;
  final String place;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('      ', style: TextStyle(fontFamily: font, fontSize: 11)),
        if (remark != null)
          Text(
            remark!.$1,
            style: TextStyle(
              fontFamily: font,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: remark!.$2,
            ),
          ),
        if (place.isNotEmpty)
          Expanded(
            child: Text(
              '${remark != null ? ' · ' : '· '}$place',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: font,
                fontSize: 11,
                color: FlightDeckColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _GoBackButton extends StatelessWidget {
  const _GoBackButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    return Material(
      color: enabled
          ? FlightDeckColors.surfaceElevated
          : FlightDeckColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: enabled
              ? FlightDeckColors.borderAccent
              : FlightDeckColors.borderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '← Go Back',
            style: TextStyle(
              fontFamily: font,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: enabled
                  ? FlightDeckColors.textPrimary
                  : FlightDeckColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallRouteButton extends StatelessWidget {
  const _SmallRouteButton({
    required this.text,
    required this.onTap,
    this.accentColor,
  });

  final String text;
  final VoidCallback onTap;

  /// Defaults to the palette's primary text color.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    return Material(
      color: FlightDeckColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: FlightDeckColors.borderAccent, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: font,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: accentColor ?? FlightDeckColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
