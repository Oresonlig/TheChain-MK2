/// Appens haptik (LOG, DONE, FINISH, ROUND COMPLETE). Eget reglage i Settings
/// (Niklas 2026-10-06, väg A): AV = appen vibrerar aldrig. PÅ = Flutters
/// HapticFeedback, som följer telefonens "vibration vid tryck" — är den av
/// visar Settings det och öppnar telefonens inställning. Appen kör aldrig över
/// telefonens val.
library;

import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  /// Appens reglage. Sätts av AppController (läser användarens inställning).
  static bool Function() enabled = () => true;

  static void light() {
    if (enabled()) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled()) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled()) HapticFeedback.heavyImpact();
  }

  static const _ch = MethodChannel('the_chain/rest_alarm');

  /// Telefonens "vibration vid tryck". Null = okänt (ingen Android-kod, t.ex. tester).
  static Future<bool?> touchVibrationOn() async {
    try {
      return await _ch.invokeMethod<bool>('touchVibrationOn');
    } catch (_) {
      return null;
    }
  }

  /// Öppnar telefonens ljud- och vibrationsinställningar.
  static Future<void> openSoundSettings() async {
    try {
      await _ch.invokeMethod<void>('openSoundSettings');
    } catch (_) {}
  }
}
