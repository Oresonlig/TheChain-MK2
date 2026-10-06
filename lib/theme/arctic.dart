/// Arctic Terminal — polarnatt (Niklas 2026-10-06). Mörk glaciärbotten där isen
/// är det som lyser: inre ljus, skarp vit kant, frostkorn. Avmättat isblått,
/// aldrig Nanosuits elektriska cyan. Flikarna är isflak (formen ur
/// TheChain_MK2/ideas/iceblocks.png, nederst till vänster — bara som referens).
library;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

const arctic = ChainTheme(
  name: 'Arctic',
  background: Color(0xFF03080D),
  backgroundGlow: Color(0xFF0D2738),
  accent: Color(0xFF9FD8EC),
  accentBright: Color(0xFFE6F7FD),
  success: Color(0xFF8FF0D0),
  restGold: Color(0xFFD9B768),
  textStrong: Color(0xFFEAF6FA),
  textBody: Color(0xFFC4DBE4),
  textMuted: Color(0xFF86A3B0),
  textFaint: Color(0xFF6C8794),
  surface: Color(0xFF0A1A26),
  border: Color(0xFF1C3242),
  borderStrong: Color(0xFF2C4A5E),
  glassTop: Color(0x660A1E2C), // 40 %
  glassBottom: Color(0x2E0A1E2C), // 18 %
  glassBlur: 18,
  // Lyser inifrån: ljus överkant och inre sken, mörk botten.
  raisedActive: RaisedMaterial(
    top: Color(0xFF2F6680),
    bottom: Color(0xFF0F2C3E),
    highlight: Color(0xE6F2FBFF),
    edge: Color(0xFFCDEFFB),
    glow: Color(0x40B4E6FA),
  ),
  raisedIdle: RaisedMaterial(
    top: Color(0xFF15303F),
    bottom: Color(0xFF0A1824),
    highlight: Color(0x40DCF5FF),
    edge: Color(0xFF34576B),
    glow: Color(0x00000000),
  ),
  raisedDone: RaisedMaterial(
    top: Color(0xFF0D1C28),
    bottom: Color(0xFF070F17),
    highlight: Color(0x1ADCF5FF),
    edge: Color(0xFF1E3444),
    glow: Color(0x00000000),
  ),
  secondaryAction: Color(0xFF7FB3C8),
  hexLine: Color(0x38CDEEFC), // frostens linjer
  hexEnergy: Color(0xFFE6F7FD),
  ambient: Ambient.polarNight,
  activeMark: ActiveMark.nitrogen,
  skippedMark: SkippedMark.frozen,
  doneMark: DoneMark.cleave,
  tabShape: TabShape.floe,
);
