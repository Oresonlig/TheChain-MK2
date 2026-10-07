/// Temasystemet. Ett tema = en ChainTheme med OBLIGATORISKA fält: saknas ett
/// fält byggs appen inte. Det är kompilatorns version av MK1:s check_themes.js
/// (CHECK 5–8) — och gör "status och närhet i samma kanal"-buggklassen svår att
/// skriva, eftersom varje tillstånd har ett eget namngivet fält.
library;

import 'dart:math' as math;

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

  /// Cosmic Horror: hela fliken blir ett öga — bokstaven är pupillen — som
  /// blinkar med slumpad takt (Niklas 2026-10-06). Ingen glöd att klippa.
  eye,
}

/// Formen på kort, fält och knappar.
enum CardShape {
  /// Nanosuit: raka hörn (kort lätt rundade).
  square,

  /// Cosmic Horror: blad-form (MK1) — diagonalt motsatta hörn rundade, de
  /// andra nästan skarpa: vänstersidan dippar, högersidan stiger.
  leaf,
}

/// Hur temat markerar ett ÖVERHOPPAT pass på bokstaven (status-kanalen).
/// Ska gå att läsa utan färg och aldrig vara svagare än "avklarad" (Niklas
/// 2026-10-04: hanterat, men medvetet hoppat över).
enum SkippedMark {
  /// Bokstaven dämpad som avklarad + ett X över.
  cross,

  /// Cosmic Horror: tre klösmärken i temats [ChainTheme.fail] (blodrött).
  claw,
}

/// Hur temat markerar ett AVKLARAT pass på bokstaven (status-kanalen). Fliken
/// själv bär närheten och rörs inte (Niklas 2026-10-06).
enum DoneMark {
  /// Bara dämpad färg.
  none,

  /// Cosmic Horror: förseglat — en läkt ärrlinje med stygn över bokstaven.
  scar,
}

/// Formen på upphöjda ytor (kedjans flikar, LOG, DONE, menyraden …).
enum TabShape {
  /// Nanosuit: avfasade spetsar i vänster/höger kant.
  chevron,

  /// Cosmic Horror: organisk, asymmetrisk blob — egen per flik (frö).
  blob,
}

/// Hur menyraden visar aktiv flik.
enum NavMark {
  /// Upphöjd yta under ikon + text (Nanosuit).
  raised,

  /// Cosmic Horror: en pulserande huggtand ner från menyradens kant.
  fang,
}

/// Temats rörliga bakgrund.
enum Ambient {
  none,

  /// Nanosuit: hex-väv med energivågor.
  hexField,

  /// Cosmic Horror: ådror från kanterna, bioluminiscenta pulser längs
  /// stammarna, ett svagt hjärtslag genom nätet ibland.
  veins,
}

/// Avdelarnas linje mellan rader i listor.
enum RuleStyle {
  solid,

  /// Cosmic Horror (MK1): streckad.
  dashed,
}

/// Temats småsaker — det som skiljer ett tema från en färgbyte (MK1 Cosmic
/// Horror, Niklas 2026-10-07: "ta in de med"). Obligatoriska som allt annat:
/// ett tema utan egen variant anger det neutrala värdet.
@immutable
class ThemeDetails {
  const ThemeDetails({
    required this.warmupLabel,
    required this.rule,
    required this.doneTint,
    required this.historyDate,
    required this.rampColor,
  });

  /// Uppvärmningssetens etikett (W1, W2 …).
  final Color warmupLabel;
  final RuleStyle rule;

  /// Skimret över en avklarad övning i passet; transparent = inget.
  final Color doneTint;

  /// Datumen i History.
  final FontStyle historyDate;

  /// Set-schemat "ramp" där det står i text.
  final Color rampColor;
}

/// Temats typsnitt: [display] för det stora (rubriker, kedjebokstäver,
/// knappar), [text] för det lilla (data, brödtext, etiketter).
@immutable
class ThemeType {
  const ThemeType({required this.display, required this.text, this.textWidth = 100, this.textScale = 1});

  final String display;
  final String text;

  /// Bredd-axeln för [text] (variabla typsnitt; ignoreras annars).
  final double textWidth;

  /// Storlek för [text] relativt Sairas skala (breda typsnitt behöver mindre).
  final double textScale;
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
    required this.ambient,
    required this.activeMark,
    required this.skippedMark,
    required this.doneMark,
    required this.tabShape,
    required this.navMark,
    required this.fonts,
    required this.cardShape,
    required this.details,
    Color? fail,
  }) : fail = fail ?? restGold;

  final CardShape cardShape;
  final ThemeDetails details;

  /// Avdelare ovanför en rad i en lista ([ThemeDetails.rule]).
  Decoration get ruleAbove => switch (details.rule) {
        RuleStyle.solid => BoxDecoration(border: Border(top: BorderSide(color: border))),
        RuleStyle.dashed => _DashedRuleAbove(borderStrong),
      };

  /// Glaskort. Blad: MK1 `24px 6px 28px 8px / 16px 22px 12px 24px`.
  BorderRadius get cardRadius => switch (cardShape) {
        CardShape.square => BorderRadius.circular(6),
        CardShape.leaf => const BorderRadius.only(
            topLeft: Radius.elliptical(24, 16),
            topRight: Radius.elliptical(6, 22),
            bottomRight: Radius.elliptical(28, 12),
            bottomLeft: Radius.elliptical(8, 24),
          ),
      };

  /// Inmatningsfält. Blad: MK1 `8px 2px 8px 2px`.
  BorderRadius get fieldRadius => switch (cardShape) {
        CardShape.square => BorderRadius.zero,
        CardShape.leaf => const BorderRadius.only(
            topLeft: Radius.circular(9),
            topRight: Radius.circular(2),
            bottomRight: Radius.circular(9),
            bottomLeft: Radius.circular(2),
          ),
      };

  /// Knappar (LOG, DONE, GhostButton …). Blad: MK1 `16px 4px 18px 4px / 14px 6px 16px 4px`.
  BorderRadius get buttonRadius => switch (cardShape) {
        CardShape.square => BorderRadius.zero,
        CardShape.leaf => const BorderRadius.only(
            topLeft: Radius.elliptical(16, 14),
            topRight: Radius.elliptical(4, 6),
            bottomRight: Radius.elliptical(18, 16),
            bottomLeft: Radius.elliptical(4, 4),
          ),
      };

  /// Avklarat pass i kedjan — obligatoriskt.
  final DoneMark doneMark;
  final TabShape tabShape;
  final NavMark navMark;
  final ThemeType fonts;

  /// Pågående pass i kedjan — obligatoriskt: varje tema tar ställning.
  final ActiveMark activeMark;

  /// Överhoppat pass i kedjan — obligatoriskt.
  final SkippedMark skippedMark;

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

  final Ambient ambient;

  /// Temat har en rörlig bakgrund (och behöver då glas under kedjan, MK1 3.88.3).
  bool get hasAmbient => ambient != Ambient.none;

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
      ambient: t < 0.5 ? ambient : other.ambient,
      activeMark: t < 0.5 ? activeMark : other.activeMark,
      skippedMark: t < 0.5 ? skippedMark : other.skippedMark,
      doneMark: t < 0.5 ? doneMark : other.doneMark,
      tabShape: t < 0.5 ? tabShape : other.tabShape,
      navMark: t < 0.5 ? navMark : other.navMark,
      fonts: t < 0.5 ? fonts : other.fonts,
      cardShape: t < 0.5 ? cardShape : other.cardShape,
      details: t < 0.5 ? details : other.details,
      fail: c(fail, other.fail),
    );
  }
}

/// Streckad linje längs överkanten (MK1 Cosmic: `border-top:1px dashed`).
class _DashedRuleAbove extends Decoration {
  const _DashedRuleAbove(this.color);
  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _DashedRulePainter(color);
}

class _DashedRulePainter extends BoxPainter {
  _DashedRulePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final w = configuration.size?.width ?? 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 7) {
      canvas.drawLine(offset + Offset(x, .5), offset + Offset(math.min(x + 4, w), .5), paint);
    }
  }
}

TextStyle _t(String family, double size, double weight, Color color, {double spacing = 0, double width = 100}) => TextStyle(
      fontFamily: family,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontVariations: [FontVariation.weight(weight), FontVariation.width(width)],
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Flutters ThemeData för ett tema: samma typskala för alla (beslut
/// 2026-10-02), typsnitten ur [ChainTheme.fonts] — det stora (rubriker,
/// knappar, kedjan) och det lilla (data, brödtext, etiketter) — färgerna ur [c].
ThemeData buildThemeData(ChainTheme c) {
  final d = c.fonts.display, x = c.fonts.text, w = c.fonts.textWidth, k = c.fonts.textScale;
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: c.background,
    fontFamily: x,
    colorScheme: ColorScheme.dark(
      primary: c.accent,
      secondary: c.accentBright,
      surface: c.surface,
      onPrimary: c.background,
      onSurface: c.textStrong,
    ),
    textTheme: TextTheme(
      displaySmall: _t(d, 34, 800, c.textStrong, spacing: 6, width: 110),
      titleLarge: _t(d, 20, 600, c.textStrong, spacing: 1.5),
      titleMedium: _t(d, 16, 600, c.textStrong, spacing: 1),
      bodyMedium: _t(x, 15 * k, 400, c.textBody, width: w),
      bodySmall: _t(x, 12 * k, 400, c.textMuted, spacing: .5, width: w),
      labelLarge: _t(d, 14, 700, c.textStrong, spacing: 2, width: 105),
      labelSmall: _t(x, 11 * k, 600, c.textFaint, spacing: 1.5 * k, width: w),
    ),
    extensions: [c],
  );
}

extension ChainThemeX on BuildContext {
  ChainTheme get chain => Theme.of(this).extension<ChainTheme>()!;
}
