import 'package:flutter/services.dart';

/// Bridges native audio (`jet_hop.wav`, `jet_back.wav`, `jet_longer.wav`, `jet_victory.wav`),
/// tactile haptics, share sheet, and persistent JSON save storage across Android, iOS/iPadOS, and macOS.
class PlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'me.guslipkin.flights/platform',
  );

  static Future<void> onPreviewSelect({required bool hapticsEnabled}) async {
    if (!hapticsEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> onHop({
    required bool hapticsEnabled,
    required bool soundEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    if (soundEnabled) {
      await _playJet('jet_hop');
    }
  }

  static Future<void> onBacktrack({
    required bool hapticsEnabled,
    required bool soundEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
    if (soundEnabled) {
      await _playJet('jet_back');
    }
  }

  static Future<void> onLongerRoute({
    required bool hapticsEnabled,
    required bool soundEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (soundEnabled) {
      await _playJet('jet_longer');
    }
  }

  static Future<void> onVictory({
    required bool hapticsEnabled,
    required bool soundEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (soundEnabled) {
      await _playJet('jet_victory');
    }
  }

  static Future<void> _playJet(String name) async {
    try {
      await _channel.invokeMethod<void>('playSound', <String, dynamic>{
        'name': name,
      });
    } catch (_) {}
  }

  static Future<bool> shareText(String text) async {
    try {
      final shared = await _channel.invokeMethod<bool>(
        'shareText',
        <String, dynamic>{'text': text},
      );
      if (shared == true) return true;
    } catch (_) {}
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> readSaveJson() async {
    try {
      return await _channel.invokeMethod<String>('readSave');
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeSaveJson(String jsonText) async {
    try {
      await _channel.invokeMethod<void>('writeSave', <String, dynamic>{
        'json': jsonText,
      });
    } catch (_) {}
  }
}
