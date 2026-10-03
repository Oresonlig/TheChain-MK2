/// Temasystemet. Ett tema = en ChainTheme med OBLIGATORISKA fält: saknas ett
/// fält byggs appen inte. Det är kompilatorns version av MK1:s check_themes.js
/// (CHECK 5–8) — och gör "status och närhet i samma kanal"-buggklassen svår att
/// skriva, eftersom varje tillstånd har ett eget namngivet fält.
library;

import 'package:flutter/material.dart';

/// Material för en upphöjd yta (session-slider, LOG, DONE): fasad kant, ljusare
/// överkant, mörkare underkant, valfri glöd. Niklas önskemål 2026-10-02 (#2).
@immutable
class RaisedMaterial {
  const RaisedMaterial({
    required this.top,
    required this.bottom,
    required this.highlight,
    required this.edge,
    required this.glow,
  });

  final Color top;
  final Color bottom;

  /// Tunn ljus linje i överkant (inset-highlight).
  final Color highlight;
  final Color edge;

  /// Yttre glöd; transparent = ingen.
  final Color glow;

  /// Samma material i en annan kulör: varje färg behåller ljushet och alfa men
  /// får [tint]s kulör och mättnad.
  RaisedMaterial tinted(Color tint) {
    final h = HSLColor.fromColor(tint);
    Color t(Color c) => HSLColor.fromColor(c).withHue(h.hue).withSaturation(h.saturation).toColor();
    return RaisedMaterial(top: t(top), bottom: t(bottom), highlight: t(highlight), edge: t(edge), glow: t(glow));
  }

  static RaisedMaterial lerp(RaisedMaterial a, RaisedMaterial b, double t) => RaisedMaterial(
        top: Color.lerp(a.top, b.top, t)!,
        bottom: Color.lerp(a.bottom, b.bottom, t)!,
        highlight: Color.lerp(a.highlight, b.highlight, t)!,
        edge: Color.lerp(a.edge, b.edge, t)!,
        glow: Color.lerp(a.glow, b.glow, t)!,
      );
}

/// Hur temat lyfter fram ett pågående pass i kedjan (utöver den gröna pricken).
/// Sluten lista: varje tema väljer en, ett nytt tema får lägga till sin egen
/// variant (Niklas 2026-10-03: Nanosuit pulsen, Cosmic Horror/Obsidian annat).
enum ActiveMark {
  /// Bara pricken.
  none,

  /// Nanosuit: ett kort ljusspår som löper runt flikens chevron-kontur.
  tracePulse,
}

@immutable
class ChainTheme extends ThemeExtension<ChainTheme> {
  const ChainTheme({
    required this.name,
    required this.background,
    required this.backgroundGlow,
    required this.accent,
    required this.accentBright,
    required this.success,
    required this.restGold,
    required this.textStrong,
    required this.textBody,
    required this.textMuted,
    required this.textFaint,
    required this.surface,
    required this.border,
    required this.borderStrong,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBlur,
    required this.raisedActive,
    required this.raisedIdle,
    required this.raisedDone,
    required this.secondaryAction,
    required this.hexLine,
    required this.hexEnergy,
    required this.hasAmbient,
    required this.activeMark,
    Color? fail,
  }) : fail = fail ?? restGold;

  /// Pågående pass i kedjan — obligatoriskt: varje tema tar ställning.
  final ActiveMark activeMark;

  final String name;

  /// FAIL / GOAL / missat set. Förval = temats vilodagsfärg (Niklas 2026-10-03),
  /// men ett tema kan ange egen om vilodagsfärgen inte läses som "fail".
  final Color fail;

  /// LOG FAIL-knappen: temats [raisedActive] tonad i [fail] — samma djup och
  /// ljusstruktur, fail-färgens kulör. Inget tema behöver egen kod för den.
  RaisedMaterial get raisedFail => raisedActive.tinted(fail);

  final Color background;

  /// Radialt sken i överkant av bakgrunden.
  final Color backgroundGlow;
  final Color accent;
  final Color accentBright;
  final Color success;

  /// Vilodagens guld — samma tre tillstånd som passen, egen färg.
  final Color restGold;

  /// Textskalan (MK1 3.87.0): datatext ≥ 7:1, etiketter ≥ 4,5:1 mot [surface].
  final Color textStrong;
  final Color textBody;
  final Color textMuted;
  final Color textFaint;

  final Color surface;
  final Color border;
  final Color borderStrong;

  /// Frostat glas: LÅG opacitet (10–55 %) + blur — aldrig 85–94 % (MK1 3.58.6).
  final Color glassTop;
  final Color glassBottom;
  final double glassBlur;

  /// Kedjans tre tillstånd (obligatoriska): aktiv/kvar, på glänt, avklarad.
  /// Avklarad är dämpad men ALDRIG osynlig.
  final RaisedMaterial raisedActive;
  final RaisedMaterial raisedIdle;
  final RaisedMaterial raisedDone;

  /// Sekundära knappar (+ Warm-up, + Work set): dämpade, aldrig skrikiga (#3).
  final Color secondaryAction;

  final Color hexLine;
  final Color hexEnergy;

  /// Temat har en rörlig bakgrund (och behöver då glas under kedjan, MK1 3.88.3).
  final bool hasAmbient;

  @override
  ChainTheme copyWith() => this;

  @override
  ChainTheme lerp(ThemeExtension<ChainTheme>? other, double t) {
    if (other is! ChainTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChainTheme(
      name: t < 0.5 ? name : other.name,
      background: c(background, other.background),
      backgroundGlow: c(backgroundGlow, other.backgroundGlow),
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      success: c(success, other.success),
      restGold: c(restGold, other.restGold),
      textStrong: c(textStrong, other.textStrong),
      textBody: c(textBody, other.textBody),
      textMuted: c(textMuted, other.textMuted),
      textFaint: c(textFaint, other.textFaint),
      surface: c(surface, other.surface),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      glassTop: c(glassTop, other.glassTop),
      glassBottom: c(glassBottom, other.glassBottom),
      glassBlur: glassBlur + (other.glassBlur - glassBlur) * t,
      raisedActive: RaisedMaterial.lerp(raisedActive, other.raisedActive, t),
      raisedIdle: RaisedMaterial.lerp(raisedIdle, other.raisedIdle, t),
      raisedDone: RaisedMaterial.lerp(raisedDone, other.raisedDone, t),
      secondaryAction: c(secondaryAction, other.secondaryAction),
      hexLine: c(hexLine, other.hexLine),
      hexEnergy: c(hexEnergy, other.hexEnergy),
      hasAmbient: t < 0.5 ? hasAmbient : other.hasAmbient,
      activeMark: t < 0.5 ? activeMark : other.activeMark,
      fail: c(fail, other.fail),
    );
  }
}

extension ChainThemeX on BuildContext {
  ChainTheme get chain => Theme.of(this).extension<ChainTheme>()!;
}
