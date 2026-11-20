import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/flights_repository.dart';
import 'ui/flights_controller.dart';
import 'ui/flights_screen.dart';
import 'ui/theme/flight_deck_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlightsApp());
}

class FlightsApp extends StatefulWidget {
  const FlightsApp({super.key});

  @override
  State<FlightsApp> createState() => _FlightsAppState();
}

class _FlightsAppState extends State<FlightsApp> with WidgetsBindingObserver {
  FlightsController? _controller;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The System theme follows the device's light/dark mode as it changes.
  @override
  void didChangePlatformBrightness() => setState(() {});

  Future<void> _initController() async {
    try {
      final repo = await FlightsRepository.loadFromAssets();
      final ctrl = await FlightsController.create(repo);
      if (mounted) {
        // A Settings theme change must rebuild from the root, where the
        // palette is chosen.
        ctrl.addListener(_onControllerChanged);
        setState(() {
          _controller = ctrl;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
      }
    }
  }

  ThemeChoice? _lastTheme;
  DarkStyle? _lastDark;

  void _onControllerChanged() {
    final ctrl = _controller!;
    if (ctrl.themeChoice != _lastTheme || ctrl.darkStyle != _lastDark) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    _lastTheme = ctrl?.themeChoice;
    _lastDark = ctrl?.darkStyle;
    // Until the save is read, follow the device so the loading screen
    // matches its mode.
    final palette = FlightDeckPalette.resolve(
      ctrl?.themeChoice ?? ThemeChoice.system,
      ctrl?.darkStyle ?? DarkStyle.navy,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    // Set before anything below builds, since widgets read it while building.
    FlightDeckColors.current = palette;
    final isDark = palette.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: MaterialApp(
        title: 'Flights',
        debugShowCheckedModeBanner: false,
        theme: buildFlightDeckTheme(palette),
        // Rebuilds the screen (and so every color) when the palette changes.
        home: KeyedSubtree(
          key: ValueKey(palette),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final err = _loadError;
    if (err != null) {
      return Scaffold(
        backgroundColor: FlightDeckColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading flight data: $err',
              style: TextStyle(color: FlightDeckColors.warningOrange),
            ),
          ),
        ),
      );
    }
    final ctrl = _controller;
    if (ctrl == null) {
      return Scaffold(
        backgroundColor: FlightDeckColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: FlightDeckColors.accentSkyBlue,
          ),
        ),
      );
    }
    return FlightsScreen(controller: ctrl);
  }
}
