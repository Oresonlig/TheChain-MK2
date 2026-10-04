/// Nanosuit — MK2:s standardtema (Niklas 2026-10-02). Färger från MK1:s
/// Nanosuit 2.0, typsnitt Saira (beslut 2026-10-02).
library;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

const _bg = Color(0xFF050810);
const _cyan = Color(0xFF00D4FF);
const _cyanBright = Color(0xFF00FFF0);
const _ink = Color(0xFFE0FAFF);

const nanosuit = ChainTheme(
  name: 'Nanosuit',
  background: _bg,
  backgroundGlow: Color(0xFF0A1828),
  accent: _cyan,
  accentBright: _cyanBright,
  success: Color(0xFF50FF88),
  restGold: Color(0xFFC9A35A),
  textStrong: _ink,
  textBody: Color(0xFFB4D6E0),
  textMuted: Color(0xFF7FA6B4),
  textFaint: Color(0xFF5A8899),
  surface: Color(0xFF0A1628),
  border: Color(0xFF1A2A40),
  borderStrong: Color(0xFF24405C),
  glassTop: Color(0x6B081624), // 42 %
  glassBottom: Color(0x2E081624), // 18 %
  glassBlur: 18,
  raisedActive: RaisedMaterial(
    top: Color(0xFF0A6F8F),
    bottom: Color(0xFF053A50),
    highlight: Color(0x80B4F0FF),
    edge: _cyan,
    glow: Color(0x5900D4FF),
  ),
  raisedIdle: RaisedMaterial(
    top: Color(0xFF0E2A3C),
    bottom: Color(0xFF081826),
    highlight: Color(0x3380D8F0),
    edge: Color(0xFF1E4A64),
    glow: Color(0x00000000),
  ),
  raisedDone: RaisedMaterial(
    top: Color(0xFF0A1A26),
    bottom: Color(0xFF061018),
    highlight: Color(0x1A80D8F0),
    edge: Color(0xFF16303F),
    glow: Color(0x00000000),
  ),
  secondaryAction: Color(0xFF3F8FA8),
  hexLine: Color(0x1400D4FF), // 8 % — MK1 BASE
  hexEnergy: _cyanBright,
  hasAmbient: true,
  activeMark: ActiveMark.tracePulse,
  skippedMark: SkippedMark.cross,
);

const _font = 'Saira';

TextStyle _t(double size, double weight, Color color, {double spacing = 0, double width = 100}) => TextStyle(
      fontFamily: _font,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontVariations: [FontVariation.weight(weight), FontVariation.width(width)],
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData nanosuitThemeData() {
  const c = nanosuit;
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: c.background,
    fontFamily: _font,
    colorScheme: const ColorScheme.dark(
      primary: _cyan,
      secondary: _cyanBright,
      surface: Color(0xFF0A1628),
      onPrimary: _bg,
      onSurface: _ink,
    ),
    textTheme: TextTheme(
      displaySmall: _t(34, 800, c.textStrong, spacing: 6, width: 110),
      titleLarge: _t(20, 600, c.textStrong, spacing: 1.5),
      titleMedium: _t(16, 600, c.textStrong, spacing: 1),
      bodyMedium: _t(15, 400, c.textBody),
      bodySmall: _t(12, 400, c.textMuted, spacing: .5),
      labelLarge: _t(14, 700, c.textStrong, spacing: 2, width: 105),
      labelSmall: _t(11, 600, c.textFaint, spacing: 1.5),
    ),
    extensions: const [nanosuit],
  );
}
