import 'package:flutter/material.dart';

import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';

class DifficultyDialog extends StatelessWidget {
  const DifficultyDialog({
    super.key,
    required this.controller,
    required this.onOpenCustomSettings,
  });

  final FlightsController controller;
  final VoidCallback onOpenCustomSettings;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final custom = game.custom;
    final font = FlightDeckColors.monospaceFontFamily;

    final customCheck = custom.check(controller.networkProvider);
    final customCount = customCheck.$1 ?? 0;
    final customPlayable = customCheck.$2 == null;
    final customCountText = !customPlayable
        ? (customCheck.$2 ?? 'no puzzles fit')
        : custom.countIsExact()
            ? '${grouped(customCount)} puzzles'
            : '≤${grouped(customCount)} puzzles';

    final rows = <(Difficulty, String, String, bool)>[
      for (final d in Difficulty.standard)
        (
          d,
          d.description,
          '${grouped(d.puzzleCount(controller.networkProvider))} puzzles',
          true,
        ),
      (
        Difficulty.custom,
        custom.summary(),
        customCountText,
        customPlayable,
      ),
    ];

    return Dialog(
      insetPadding: DialogSizing.insetPadding(context),
      backgroundColor: FlightDeckColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: FlightDeckColors.accentSkyBlue,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: DialogSizing.maxWidth(context, 460)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT DIFFICULTY',
                        style: TextStyle(
                          fontFamily: font,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.8,
                          color: FlightDeckColors.accentSkyBlue,
                        ),
                      ),
                      Text(
                        'Tap a level to start a new game',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlightDeckColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FlightDeckColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: FlightDeckColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '✕ Close',
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 12,
                          color: FlightDeckColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (diff, desc, countText, isPlayable) in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DifficultyRowCard(
                            difficulty: diff,
                            description: desc,
                            countText: countText,
                            isCurrent: game.difficulty == diff,
                            isPlayable: isPlayable,
                            onSelect: () {
                              Navigator.of(context).pop();
                              if (diff == Difficulty.custom && !isPlayable) {
                                onOpenCustomSettings();
                              } else {
                                controller.startNewGame(diff);
                              }
                            },
                            onCustomize: diff == Difficulty.custom
                                ? () {
                                    Navigator.of(context).pop();
                                    onOpenCustomSettings();
                                  }
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyRowCard extends StatelessWidget {
  const _DifficultyRowCard({
    required this.difficulty,
    required this.description,
    required this.countText,
    required this.isCurrent,
    required this.isPlayable,
    required this.onSelect,
    this.onCustomize,
  });

  final Difficulty difficulty;
  final String description;
  final String countText;
  final bool isCurrent;
  final bool isPlayable;
  final VoidCallback onSelect;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    final borderColor = isCurrent
        ? FlightDeckColors.accentSkyBlue
        : !isPlayable
            ? FlightDeckColors.warningOrange.withValues(alpha: 0.6)
            : FlightDeckColors.borderSubtle;
    final bgColor = isCurrent
        ? FlightDeckColors.accentSkyBlue.withValues(alpha: 0.12)
        : FlightDeckColors.surfaceElevated;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        difficulty.label,
                        style: TextStyle(
                          fontFamily: font,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCurrent
                              ? FlightDeckColors.accentSkyBlue
                              : FlightDeckColors.textPrimary,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: FlightDeckColors.accentSkyBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              fontFamily: font,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: FlightDeckColors.onAccent,
                            ),
                          ),
                        ),
                      ],
                      if (difficulty == Difficulty.medium) ...[
                        const SizedBox(width: 8),
                        Text(
                          'default & daily',
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 10,
                            color: FlightDeckColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    countText,
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: isPlayable
                          ? FlightDeckColors.positiveGreen
                          : FlightDeckColors.warningOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: FlightDeckColors.textSecondary,
                      ),
                    ),
                  ),
                  if (onCustomize != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onCustomize,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: FlightDeckColors.surfaceCard,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: FlightDeckColors.borderAccent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Customize…',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: FlightDeckColors.accentSkyBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
