import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';
import 'keep_visible.dart';

/// Builds a rich `TextSpan` for a 3-letter airport code with its changed letter (0..2)
/// highlighted in bold Orange, plus an optional `★` star for the destination airport.
TextSpan styledAirportCodeSpan({
  required String code,
  required int? changedIndex,
  required Color baseColor,
  double fontSize = 14.0,
  bool isDestination = false,
}) {
  final font = FlightDeckColors.monospaceFontFamily;
  return TextSpan(
    children: [
      for (var i = 0; i < code.length; i++)
        TextSpan(
          text: code[i],
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color:
                changedIndex == i ? FlightDeckColors.warningOrange : baseColor,
          ),
        ),
      if (isDestination)
        TextSpan(
          text: '★',
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color: FlightDeckColors.destinationPurple,
          ),
        ),
    ],
  );
}

class OptionsPanel extends StatelessWidget {
  const OptionsPanel({super.key, required this.controller});

  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final net = controller.currentNetwork;
    final options = controller.options;
    final font = FlightDeckColors.monospaceFontFamily;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlightDeckColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OPTIONS (${options.length})',
                style: TextStyle(
                  fontFamily: font,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: FlightDeckColors.accentSkyBlue,
                ),
              ),
              if (options.isNotEmpty) ...[
                const SizedBox(width: 8),
                // The landscape side column can be narrower than the hint.
                Flexible(
                  child: Text(
                    (Platform.isMacOS || Platform.isWindows)
                        ? 'Click to fly · ↑↓ to preview'
                        : controller.oneTapToFly
                            ? 'Tap to fly'
                            : 'Tap to preview · Tap again or Fly',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: FlightDeckColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: options.isEmpty
                ? _EmptyOptionsView(controller: controller)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 3),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected =
                          index == controller.selectedOptionIndex;
                      final isDest = opt.airport == game.destination;
                      return KeepVisible(
                        active: isSelected,
                        child: _OptionRow(
                          option: opt,
                          isSelected: isSelected,
                          isDestination: isDest,
                          showDistances: game.rules.showsDistances(),
                          showPlaces: game.rules.showPlaces,
                          showVia: game.rules.showsConnections(),
                          placeText: shortPlace(net.place(opt.airport)),
                          formattedDistance: game.units.format(opt.distance),
                          onRowTap: (kind) =>
                              controller.onOptionTapped(index, kind: kind),
                          onFlyTap: controller.flyToSelected,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOptionsView extends StatelessWidget {
  const _EmptyOptionsView({required this.controller});
  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final font = FlightDeckColors.monospaceFontFamily;
    final emptyText = game.status == GameStatus.playing && game.atDestination()
        ? "You're at the destination by a longer route. Tap Go Back to try another way."
        : game.status == GameStatus.playing
            ? 'No tickets from here to an airport not already on your route. Tap Go Back.'
            : 'The game is over. Start a New Game or Daily Challenge to play again.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: FlightDeckColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (game.status == GameStatus.playing && game.hops > 0)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: controller.goBack,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: FlightDeckColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlightDeckColors.warningOrange,
                    width: 1,
                  ),
                ),
                child: Text(
                  '← Go Back',
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: FlightDeckColors.warningOrange,
                  ),
                ),
              ),
            )
          else if (game.status != GameStatus.playing)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => controller.startNewGame(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: FlightDeckColors.accentSkyBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlightDeckColors.accentSkyBlue,
                    width: 1,
                  ),
                ),
                child: Text(
                  'New Game',
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: FlightDeckColors.accentSkyBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.isDestination,
    required this.showDistances,
    required this.showPlaces,
    required this.showVia,
    required this.placeText,
    required this.formattedDistance,
    required this.onRowTap,
    required this.onFlyTap,
  });

  final FlightOption option;
  final bool isSelected;
  final bool isDestination;
  final bool showDistances;
  final bool showPlaces;
  final bool showVia;
  final String placeText;
  final String formattedDistance;
  final void Function(PointerDeviceKind kind) onRowTap;
  final VoidCallback onFlyTap;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    final bgColor = isSelected
        ? FlightDeckColors.selectedRowBg
        : FlightDeckColors.surfaceElevated;
    final borderColor = isSelected
        ? FlightDeckColors.selectedRowBorder
        : isDestination
            ? FlightDeckColors.destinationPurple.withValues(alpha: 0.55)
            : FlightDeckColors.borderSubtle;
    final baseCodeColor = isDestination
        ? FlightDeckColors.destinationPurple
        : FlightDeckColors.textPrimary;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        // onTapUp rather than onTap: it says whether this was a mouse or a
        // finger, which decide whether the first tap flies.
        onTapUp: (details) => onRowTap(details.kind),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              Text(
                isSelected ? '> ' : '  ',
                style: TextStyle(
                  fontFamily: font,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: FlightDeckColors.warningOrange,
                ),
              ),
              SizedBox(
                width: 44,
                child: RichText(
                  text: styledAirportCodeSpan(
                    code: option.code,
                    changedIndex: option.changed,
                    baseColor: baseCodeColor,
                    fontSize: 14,
                    isDestination: isDestination,
                  ),
                ),
              ),
              if (showDistances)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    formattedDistance,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 11.5,
                      color: FlightDeckColors.textSecondary,
                    ),
                  ),
                ),
              // City and connections share what's left after the code,
              // distance and Fly button, so neither pushes the row past a
              // narrow landscape side column; the city gets the larger share.
              Expanded(
                flex: (showPlaces && placeText.isNotEmpty) ? 3 : 1,
                child: (showPlaces && placeText.isNotEmpty)
                    ? Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          placeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: FlightDeckColors.textPrimary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (showVia)
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      option.via.isEmpty
                          ? 'direct'
                          : 'via ${option.via.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: 11.5,
                        color: FlightDeckColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onFlyTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: FlightDeckColors.warningOrange,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Fly →',
                      style: TextStyle(
                        fontFamily: font,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: FlightDeckColors.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
