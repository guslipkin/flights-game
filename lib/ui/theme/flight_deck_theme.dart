import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The app-wide theme setting: follow the device, or force light or dark.
enum ThemeChoice {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemeChoice(this.label);
  final String label;

  static ThemeChoice fromName(String? raw) => ThemeChoice.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => ThemeChoice.system,
      );
}

/// Which palette "dark" means: the original navy, or pure black (OLED).
enum DarkStyle {
  navy('Navy'),
  black('Black');

  const DarkStyle(this.label);
  final String label;

  static DarkStyle fromName(String? raw) => DarkStyle.values.firstWhere(
        (d) => d.name == raw,
        orElse: () => DarkStyle.navy,
      );
}

/// One complete set of UI colors. Accents are the Okabe-Ito colorblind-safe
/// palette from jotto-cli; the light palette uses darker variants of them so
/// text in those colors stays readable on white.
class FlightDeckPalette {
  const FlightDeckPalette({
    required this.brightness,
    required this.background,
    required this.radarBackground,
    required this.radarGrid,
    required this.coastlineVector,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.selectedRowBg,
    required this.selectedRowBorder,
    required this.borderSubtle,
    required this.borderAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentSkyBlue,
    required this.positiveGreen,
    required this.warningOrange,
    required this.destinationPurple,
    required this.negativeVermilion,
    required this.onAccent,
  });

  final Brightness brightness;
  final Color background;
  final Color radarBackground;
  final Color radarGrid;
  final Color coastlineVector;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color selectedRowBg;
  final Color selectedRowBorder;
  final Color borderSubtle;
  final Color borderAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentSkyBlue;
  final Color positiveGreen;
  final Color warningOrange;
  final Color destinationPurple;
  final Color negativeVermilion;

  /// Text drawn on a filled accent badge or button.
  final Color onAccent;

  static const FlightDeckPalette navy = FlightDeckPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0D1117),
    radarBackground: Color(0xFF090D12),
    radarGrid: Color(0xFF121C29),
    coastlineVector: Color(0xFF475B73),
    surfaceCard: Color(0xFF131A24),
    surfaceElevated: Color(0xFF1A2331),
    selectedRowBg: Color(0xFF28261E),
    selectedRowBorder: Color(0xFFE69F00),
    borderSubtle: Color(0xFF233246),
    borderAccent: Color(0xFF334C6B),
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF9BAEC4),
    textMuted: Color(0xFF63768D),
    accentSkyBlue: Color(0xFF56B4E9),
    positiveGreen: Color(0xFF009E73),
    warningOrange: Color(0xFFE69F00),
    destinationPurple: Color(0xFFCC79A7),
    negativeVermilion: Color(0xFFD55E00),
    onAccent: Color(0xFF000000),
  );

  static const FlightDeckPalette black = FlightDeckPalette(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    radarBackground: Color(0xFF000000),
    radarGrid: Color(0xFF10151B),
    coastlineVector: Color(0xFF3E4A58),
    surfaceCard: Color(0xFF0A0A0A),
    surfaceElevated: Color(0xFF151515),
    selectedRowBg: Color(0xFF231E10),
    selectedRowBorder: Color(0xFFE69F00),
    borderSubtle: Color(0xFF24292F),
    borderAccent: Color(0xFF3A4450),
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF9BAEC4),
    textMuted: Color(0xFF66717E),
    accentSkyBlue: Color(0xFF56B4E9),
    positiveGreen: Color(0xFF009E73),
    warningOrange: Color(0xFFE69F00),
    destinationPurple: Color(0xFFCC79A7),
    negativeVermilion: Color(0xFFD55E00),
    onAccent: Color(0xFF000000),
  );

  static const FlightDeckPalette light = FlightDeckPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F5F8),
    radarBackground: Color(0xFFEAF1F7),
    radarGrid: Color(0xFFD7E1EB),
    coastlineVector: Color(0xFF8396AB),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F3F7),
    selectedRowBg: Color(0xFFFFF1D2),
    selectedRowBorder: Color(0xFFB36B00),
    borderSubtle: Color(0xFFD3DBE4),
    borderAccent: Color(0xFFA6B6C8),
    textPrimary: Color(0xFF0D1117),
    textSecondary: Color(0xFF475769),
    textMuted: Color(0xFF6E7F93),
    accentSkyBlue: Color(0xFF0072B2),
    positiveGreen: Color(0xFF007A5A),
    warningOrange: Color(0xFFB36B00),
    destinationPurple: Color(0xFFA6487F),
    negativeVermilion: Color(0xFFB84F00),
    onAccent: Color(0xFFFFFFFF),
  );

  static FlightDeckPalette resolve(
    ThemeChoice choice,
    DarkStyle darkStyle,
    Brightness platformBrightness,
  ) {
    final dark = switch (choice) {
      ThemeChoice.light => false,
      ThemeChoice.dark => true,
      ThemeChoice.system => platformBrightness == Brightness.dark,
    };
    if (!dark) return light;
    return darkStyle == DarkStyle.black ? black : navy;
  }
}

/// The colors every widget draws with, from the [current] palette.
///
/// These are static getters over one global palette rather than a
/// `Theme.of(context)` lookup because ~270 call sites (the map painter and
/// span helpers among them) have no `BuildContext`. The app root sets
/// [current] before building, and a theme change rebuilds the whole tree.
class FlightDeckColors {
  static FlightDeckPalette current = FlightDeckPalette.navy;

  static Color get background => current.background;
  static Color get radarBackground => current.radarBackground;
  static Color get radarGrid => current.radarGrid;
  static Color get coastlineVector => current.coastlineVector;
  static Color get surfaceCard => current.surfaceCard;
  static Color get surfaceElevated => current.surfaceElevated;
  static Color get selectedRowBg => current.selectedRowBg;
  static Color get selectedRowBorder => current.selectedRowBorder;
  static Color get borderSubtle => current.borderSubtle;
  static Color get borderAccent => current.borderAccent;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textMuted => current.textMuted;
  static Color get accentSkyBlue => current.accentSkyBlue;
  static Color get positiveGreen => current.positiveGreen;
  static Color get warningOrange => current.warningOrange;
  static Color get destinationPurple => current.destinationPurple;
  static Color get negativeVermilion => current.negativeVermilion;
  static Color get onAccent => current.onAccent;

  static String get monospaceFontFamily {
    if (kIsWeb) return 'monospace';
    if (Platform.isIOS || Platform.isMacOS) return 'Menlo';
    return 'monospace';
  }
}

ThemeData buildFlightDeckTheme(FlightDeckPalette p) {
  final base = p.brightness == Brightness.dark
      ? const ColorScheme.dark()
      : const ColorScheme.light();
  return ThemeData(
    brightness: p.brightness,
    scaffoldBackgroundColor: p.background,
    colorScheme: base.copyWith(
      primary: p.accentSkyBlue,
      onPrimary: p.onAccent,
      secondary: p.positiveGreen,
      onSecondary: p.onAccent,
      tertiary: p.destinationPurple,
      surface: p.surfaceCard,
      onSurface: p.textPrimary,
      error: p.negativeVermilion,
    ),
    useMaterial3: true,
  );
}

/// Dialog sizing. The portrait widths suit phones, but in landscape they left
/// most of the screen empty and made the content scroll, so landscape dialogs
/// grow with the window (capped so lines stay readable).
class DialogSizing {
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  static double maxWidth(BuildContext context, double portraitMax) {
    if (!isLandscape(context)) return portraitMax;
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.75).clamp(portraitMax, 900.0);
  }

  /// Landscape has little height to spare, so the margins shrink there.
  static EdgeInsets insetPadding(BuildContext context) {
    return isLandscape(context)
        ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
  }
}
