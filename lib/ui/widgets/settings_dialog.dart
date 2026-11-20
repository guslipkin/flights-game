import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/network.dart';
import '../../game/flights_game.dart';
import '../flights_controller.dart';
import '../theme/flight_deck_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.controller});

  final FlightsController controller;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late Units _units;
  late bool _curves;
  late bool _haptics;
  late bool _sound;
  late ThemeChoice _theme;
  late DarkStyle _dark;
  late bool _oneTap;
  late Rules _custom;
  late TextEditingController _startController;
  late TextEditingController _endController;
  String? _problem;

  @override
  void initState() {
    super.initState();
    final ctrl = widget.controller;
    final game = ctrl.game;
    _units = game.units;
    _curves = game.curves;
    _haptics = ctrl.hapticsEnabled;
    _sound = ctrl.soundEnabled;
    _theme = ctrl.themeChoice;
    _dark = ctrl.darkStyle;
    _oneTap = ctrl.oneTapToFly;
    _custom = game.custom;
    _startController = TextEditingController(text: _custom.start ?? '');
    _endController = TextEditingController(text: _custom.end ?? '');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  int _stepIndex(int current, int size, bool forward) {
    return forward ? (current + 1) % size : (current + size - 1) % size;
  }

  void _stepViewPreset(bool forward) {
    const all = Difficulty.standard;
    final curLvl = _custom.view.level();
    final curIdx = curLvl != null ? all.indexOf(curLvl) : -1;
    final nextIdx = curIdx >= 0
        ? _stepIndex(curIdx, all.length, forward)
        : (forward ? 0 : all.length - 1);
    setState(() {
      _custom = _custom.copyWith(view: ViewConfig.of(all[nextIdx]));
      _problem = null;
    });
  }

  void _stepMinHops(bool forward) {
    final top = _custom.maxHops ?? maxHopsLimit;
    final choices = [for (var h = minHopsLimit; h <= top; h++) h];
    final idx = choices.indexOf(_custom.minHops);
    final curIdx = idx >= 0 ? idx : 0;
    setState(() {
      _custom = _custom.copyWith(
        minHops: choices[_stepIndex(curIdx, choices.length, forward)],
      );
      _problem = null;
    });
  }

  void _stepMaxHops(bool forward) {
    final choices = <int?>[
      for (var h = _custom.minHops; h <= maxHopsLimit; h++) h,
      null,
    ];
    final idx = choices.indexOf(_custom.maxHops);
    final curIdx = idx >= 0 ? idx : 0;
    setState(() {
      _custom = _custom.copyWith(
        maxHops: choices[_stepIndex(curIdx, choices.length, forward)],
      );
      _problem = null;
    });
  }

  void _closeAndSave({required bool playCustom}) {
    final err = widget.controller.applySettings(
      units: _units,
      curves: _curves,
      haptics: _haptics,
      sound: _sound,
      theme: _theme,
      dark: _dark,
      oneTap: _oneTap,
      custom: _custom,
      playCustom: playCustom,
    );
    if (err != null) {
      setState(() => _problem = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    final checkResult = _custom.check(widget.controller.networkProvider);
    final puzzleCount = checkResult.$1 ?? 0;
    final statusErr = checkResult.$2;
    final reuseEnabled = _custom.connections() > 0;

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
        constraints: BoxConstraints(
            maxWidth: DialogSizing.maxWidth(context, 480), maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.0,
                      color: FlightDeckColors.accentSkyBlue,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _closeAndSave(playCustom: false),
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
              const SizedBox(height: 8),

              // Scrollable Rows
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader('Preferences', font: font),
                      const SizedBox(height: 4),
                      _StepperSettingRow(
                        label: 'Units',
                        value: _units.label,
                        note: 'distance units (Default: nm)',
                        enabled: true,
                        onStep: (forward) {
                          const all = Units.values;
                          setState(() {
                            _units = all[
                                _stepIndex(_units.index, all.length, forward)];
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Map lines',
                        value: _curves ? 'Curved' : 'Straight',
                        note: "the hops' shape (Default: Curved)",
                        enabled: true,
                        onStep: (_) => setState(() => _curves = !_curves),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Tap to fly',
                        value: _oneTap ? 'One tap' : 'Two taps',
                        note: _oneTap
                            ? 'touch: tapping an option flies there'
                            : 'touch: tap to preview, again to fly (Default)',
                        enabled: true,
                        onStep: (_) => setState(() => _oneTap = !_oneTap),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Haptics',
                        value: _haptics ? 'On' : 'Off',
                        note: 'tactile feedback on hops',
                        enabled: true,
                        onStep: (_) => setState(() => _haptics = !_haptics),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Sound',
                        value: _sound ? 'On' : 'Off',
                        note: 'jet sound effects',
                        enabled: true,
                        onStep: (_) => setState(() => _sound = !_sound),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Theme',
                        value: _theme.label,
                        note: 'System follows the device (Default)',
                        enabled: true,
                        onStep: (forward) {
                          const all = ThemeChoice.values;
                          setState(() {
                            _theme = all[
                                _stepIndex(_theme.index, all.length, forward)];
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Dark style',
                        value: _dark.label,
                        note: _theme == ThemeChoice.light
                            ? 'not used by the Light theme'
                            : 'Black suits OLED screens',
                        enabled: _theme != ThemeChoice.light,
                        indented: true,
                        onStep: (_) => setState(() {
                          _dark = _dark == DarkStyle.navy
                              ? DarkStyle.black
                              : DarkStyle.navy;
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: FlightDeckColors.borderSubtle,
                        ),
                      ),
                      _SectionHeader('Custom game', font: font),
                      const SizedBox(height: 4),
                      _StepperSettingRow(
                        label: 'Shows',
                        value: _custom.view.label(),
                        note: 'sets the 4 below as a level does',
                        enabled: true,
                        onStep: _stepViewPreset,
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Map',
                        value: _custom.view.map ? 'On' : 'Off',
                        note: 'else a list of codes',
                        enabled: true,
                        indented: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            view: _custom.view.copyWith(
                              map: !_custom.view.map,
                            ),
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Distances',
                        value: _custom.view.distances ? 'On' : 'Off',
                        note: 'while playing',
                        enabled: true,
                        indented: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            view: _custom.view.copyWith(
                              distances: !_custom.view.distances,
                            ),
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Connections',
                        value: _custom.view.connections ? 'On' : 'Off',
                        note: 'where hops connect',
                        enabled: true,
                        indented: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            view: _custom.view.copyWith(
                              connections: !_custom.view.connections,
                            ),
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'How far over',
                        value: _custom.view.amountOver ? 'On' : 'Off',
                        note: 'when you arrive the long way',
                        enabled: true,
                        indented: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            view: _custom.view.copyWith(
                              amountOver: !_custom.view.amountOver,
                            ),
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'City, country',
                        value: _custom.showPlaces ? 'On' : 'Off',
                        note: 'beside each option',
                        enabled: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            showPlaces: !_custom.showPlaces,
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Puzzles',
                        value: _custom.fixedRoute ? 'Route' : 'Random',
                        note: _custom.fixedRoute
                            ? 'your start and end, any length'
                            : 'random, within the limits',
                        enabled: true,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            fixedRoute: !_custom.fixedRoute,
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Max connections',
                        value: _custom.maxConnections.toString(),
                        note: !_custom.fixedRoute
                            ? "per hop's ticket"
                            : 'not used for a fixed route',
                        enabled: !_custom.fixedRoute,
                        onStep: (forward) => setState(() {
                          _custom = _custom.copyWith(
                            maxConnections: _stepIndex(
                              _custom.maxConnections,
                              maxConnectionsLimit + 1,
                              forward,
                            ),
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Reuse connections',
                        value: _custom.reuseConnections ? 'Yes' : 'No',
                        note: !reuseEnabled
                            ? 'no connections to reuse'
                            : _custom.reuseConnections
                                ? 'airports may repeat as connections'
                                : 'each airport once, connections too',
                        enabled: reuseEnabled,
                        onStep: (_) => setState(() {
                          _custom = _custom.copyWith(
                            reuseConnections: !_custom.reuseConnections,
                          );
                          _problem = null;
                        }),
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Min hops',
                        value: _custom.minHops.toString(),
                        note: !_custom.fixedRoute
                            ? 'in the best route (3-20)'
                            : 'not used for a fixed route',
                        enabled: !_custom.fixedRoute,
                        onStep: _stepMinHops,
                      ),
                      const SizedBox(height: 5),
                      _StepperSettingRow(
                        label: 'Max hops',
                        value: _custom.maxHops?.toString() ?? 'No limit',
                        note: !_custom.fixedRoute
                            ? 'in the best route (3-20)'
                            : 'not used for a fixed route',
                        enabled: !_custom.fixedRoute,
                        onStep: _stepMaxHops,
                      ),
                      const SizedBox(height: 5),
                      _CodeInputSettingRow(
                        label: 'Start',
                        controller: _startController,
                        enabled: _custom.fixedRoute,
                        onChanged: (raw) {
                          final clean = raw.toUpperCase();
                          setState(() {
                            _custom = _custom.copyWith(start: parseCode(clean));
                            _problem = null;
                          });
                        },
                        onClear: () {
                          _startController.clear();
                          setState(() {
                            _custom = _custom.copyWith(start: null);
                            _problem = null;
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      _CodeInputSettingRow(
                        label: 'End',
                        controller: _endController,
                        enabled: _custom.fixedRoute,
                        onChanged: (raw) {
                          final clean = raw.toUpperCase();
                          setState(() {
                            _custom = _custom.copyWith(end: parseCode(clean));
                            _problem = null;
                          });
                        },
                        onClear: () {
                          _endController.clear();
                          setState(() {
                            _custom = _custom.copyWith(end: null);
                            _problem = null;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Defaults',
                                style: TextStyle(
                                  fontFamily: font,
                                  fontSize: 12.5,
                                  color: FlightDeckColors.textPrimary,
                                ),
                              ),
                              Text(
                                'custom settings to defaults',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FlightDeckColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              _startController.clear();
                              _endController.clear();
                              setState(() {
                                _custom = const Rules();
                                _problem = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: FlightDeckColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: FlightDeckColors.borderAccent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  fontFamily: font,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: FlightDeckColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: FlightDeckColors.borderSubtle,
                ),
              ),

              // Live Puzzle Count & Validation Status
              if (_problem != null)
                Text(
                  _problem!,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: FlightDeckColors.warningOrange,
                  ),
                )
              else if (statusErr != null)
                Text(
                  "Can't play these settings: $statusErr.",
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: FlightDeckColors.warningOrange,
                  ),
                )
              else
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _custom.countIsExact()
                            ? 'Puzzles with these settings: '
                            : 'Puzzles with these settings: up to ',
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 12,
                          color: FlightDeckColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: grouped(puzzleCount),
                        style: TextStyle(
                          fontFamily: font,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: FlightDeckColors.positiveGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                "Levels' max hops: Easy 4, Medium 6, Hard 8, Pilot none",
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 11,
                  color: FlightDeckColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              // Footer Buttons
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _closeAndSave(playCustom: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FlightDeckColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FlightDeckColors.borderAccent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Save & Close',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FlightDeckColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 12,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _closeAndSave(playCustom: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: statusErr == null
                              ? FlightDeckColors.accentSkyBlue
                              : FlightDeckColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusErr == null
                                ? FlightDeckColors.accentSkyBlue
                                : FlightDeckColors.warningOrange,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Play Custom',
                          style: TextStyle(
                            fontFamily: font,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: statusErr == null
                                ? FlightDeckColors.onAccent
                                : FlightDeckColors.warningOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.font});
  final String title;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: FlightDeckColors.accentSkyBlue,
      ),
    );
  }
}

class _StepperSettingRow extends StatelessWidget {
  const _StepperSettingRow({
    required this.label,
    required this.value,
    required this.note,
    required this.enabled,
    required this.onStep,
    this.indented = false,
  });

  final String label;
  final String value;
  final String note;
  final bool enabled;
  final bool indented;
  final void Function(bool forward) onStep;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: FlightDeckColors.surfaceElevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: indented ? 16.0 : 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: 12,
                        color: FlightDeckColors.textPrimary,
                      ),
                    ),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 11,
                        color: FlightDeckColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepArrowButton(
                  symbol: '◀',
                  enabled: enabled,
                  onTap: () => onStep(false),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: FlightDeckColors.textPrimary,
                    ),
                  ),
                ),
                _StepArrowButton(
                  symbol: '▶',
                  enabled: enabled,
                  onTap: () => onStep(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepArrowButton extends StatelessWidget {
  const _StepArrowButton({
    required this.symbol,
    required this.enabled,
    required this.onTap,
  });

  final String symbol;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FlightDeckColors.surfaceCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: FlightDeckColors.borderSubtle, width: 1),
        ),
        child: Text(
          symbol,
          style: TextStyle(
            fontFamily: font,
            fontSize: 11,
            color: FlightDeckColors.accentSkyBlue,
          ),
        ),
      ),
    );
  }
}

class _CodeInputSettingRow extends StatelessWidget {
  const _CodeInputSettingRow({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onClear,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final font = FlightDeckColors.monospaceFontFamily;
    final note = enabled
        ? 'type 3-letter code; ✕ clears to random'
        : 'only for a fixed route';

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: FlightDeckColors.surfaceElevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 12,
                      color: FlightDeckColors.textPrimary,
                    ),
                  ),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 11,
                      color: FlightDeckColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 78,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlightDeckColors.radarBackground,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: controller.text.length == 3
                      ? FlightDeckColors.accentSkyBlue
                      : FlightDeckColors.borderAccent,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                textAlign: TextAlign.center,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                ],
                style: TextStyle(
                  fontFamily: font,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: FlightDeckColors.textPrimary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                  hintText: 'Random',
                  hintStyle: TextStyle(
                    fontFamily: font,
                    fontSize: 11.5,
                    color: FlightDeckColors.textMuted,
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
            if (enabled && controller.text.isNotEmpty) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlightDeckColors.surfaceCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: FlightDeckColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '✕',
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 11,
                      color: FlightDeckColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
