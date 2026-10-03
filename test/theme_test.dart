import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/nanosuit.dart';

ChainTheme _withFail(Color? fail) => ChainTheme(
      name: 'x',
      background: nanosuit.background,
      backgroundGlow: nanosuit.backgroundGlow,
      accent: nanosuit.accent,
      accentBright: nanosuit.accentBright,
      success: nanosuit.success,
      restGold: const Color(0xFF9B6BFF), // ett tema med lila vilodag
      textStrong: nanosuit.textStrong,
      textBody: nanosuit.textBody,
      textMuted: nanosuit.textMuted,
      textFaint: nanosuit.textFaint,
      surface: nanosuit.surface,
      border: nanosuit.border,
      borderStrong: nanosuit.borderStrong,
      glassTop: nanosuit.glassTop,
      glassBottom: nanosuit.glassBottom,
      glassBlur: nanosuit.glassBlur,
      raisedActive: nanosuit.raisedActive,
      raisedIdle: nanosuit.raisedIdle,
      raisedDone: nanosuit.raisedDone,
      secondaryAction: nanosuit.secondaryAction,
      hexLine: nanosuit.hexLine,
      hexEnergy: nanosuit.hexEnergy,
      hasAmbient: true,
      activeMark: ActiveMark.none,
      fail: fail,
    );

void main() {
  test('fail: förval = temats vilodagsfärg, kan åsidosättas', () {
    expect(nanosuit.fail, nanosuit.restGold);
    expect(_withFail(null).fail, const Color(0xFF9B6BFF));
    expect(_withFail(Colors.orange).fail, Colors.orange);
  });

  test('LOG FAIL-ytan: temats raisedActive i fail-färgens kulör, samma ljushet', () {
    final t = _withFail(null);
    final hue = HSLColor.fromColor(t.fail).hue;
    for (final (a, f) in [
      (t.raisedActive.top, t.raisedFail.top),
      (t.raisedActive.bottom, t.raisedFail.bottom),
      (t.raisedActive.edge, t.raisedFail.edge),
    ]) {
      expect(HSLColor.fromColor(f).hue, closeTo(hue, 1));
      expect(HSLColor.fromColor(f).lightness, closeTo(HSLColor.fromColor(a).lightness, .01));
      expect(f.a, closeTo(a.a, .01));
    }
  });
}
