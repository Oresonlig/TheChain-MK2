/// Nano Sakura — ljust tema, "Nanosuit i en annan lackering" (Niklas
/// 2026-10-14, design: Claude Design, källa i design/nano_sakura/).
/// Pärlvit botten, Orchid-accent, rosa hex-väv. Quicksand överallt, Saira
/// för siffrorna i set-raden.
library;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

const _bg = Color(0xFFFBF5F8);
const _orchid = Color(0xFF9C2A7A);
const _orchidBright = Color(0xFFE06BC0);
const _ink = Color(0xFF2A0F1E);
const _muted = Color(0xFF7A5A6A);

const nanoSakura = ChainTheme(
  name: 'Nano Sakura',
  background: _bg,
  backgroundGlow: Color(0xFFFFE4EE),
  accent: _orchid,
  accentBright: _orchidBright,
  onAccent: Color(0xFFFFFFFF),
  success: Color(0xFF23794A),
  restGold: Color(0xFF7B4B94), // plommon — guld fungerar inte på rosa/vitt
  fail: Color(0xFFD84315), // varmt rött, tydligt skilt från orchid
  textStrong: _ink,
  textBody: Color(0xFF4E3341),
  textMuted: _muted,
  textFaint: Color(0xFF9C7D8C),
  surface: Color(0xFFFFFFFF),
  border: Color(0xFFF0D6E1),
  borderStrong: Color(0xFFE3B5C8),
  // Tunnare glas (Niklas 2026-10-15: "syns knappt något bakom"). Som Cosmic:
  // blurren dolde mest — 18 → 4; vitt glas på ljus botten täcker dessutom.
  glassTop: Color(0x73FFFFFF), // 45 %
  glassBottom: Color(0x4DFFF0F5), // 30 %
  glassBlur: 4,
  raisedActive: RaisedMaterial(
    top: Color(0xFFAE3D8B),
    bottom: Color(0xFF842166),
    highlight: Color(0x80FFFFFF),
    edge: Color(0xFF66144F),
    glow: Color(0x479C2A7A), // mjuk skugga, inte neon
  ),
  raisedIdle: RaisedMaterial(
    top: Color(0xFFFFFFFF),
    bottom: Color(0xFFFCEAF1),
    highlight: Color(0xFFFFFFFF),
    edge: Color(0xFFE3B5C8),
    glow: Color(0x00000000),
  ),
  raisedDone: RaisedMaterial(
    top: Color(0xFFF6EEF2),
    bottom: Color(0xFFEEE2E8),
    highlight: Color(0x80FFFFFF),
    edge: Color(0xFFDCC9D2),
    glow: Color(0x00000000),
  ),
  secondaryAction: Color(0xFF9E5A7A),
  hexLine: Color(0x1F9C2A7A), // 12 %
  hexEnergy: _orchidBright,
  waveWidth: 1, // Nanosuits våg rakt av, inverterad (Niklas 2026-10-15; 2.4 kändes inte som Nanosuit)
  ambient: Ambient.hexFieldPetals,
  activeMark: ActiveMark.tracePulse,
  skippedMark: SkippedMark.cross,
  doneMark: DoneMark.none,
  tabShape: TabShape.petalNotch,
  navMark: NavMark.raised,
  fonts: ThemeType(display: 'Quicksand', text: 'Quicksand', numbers: 'Saira'),
  cardShape: CardShape.square,
  // Mörkt plommon (Claude Design: namn #FCEAF1, sekundärt #C9A7B8). Resten av
  // skalan härledd för mörk botten — kontrasttestet prövar den.
  darkCard: DarkCard(
    top: Color(0xF03A1530),
    bottom: Color(0xEB24091C),
    edge: Color(0xFF4A1D3C),
    borderStrong: Color(0xFF6B3459),
    textStrong: Color(0xFFFCEAF1),
    textBody: Color(0xFFE6CCD8),
    textMuted: Color(0xFFC9A7B8),
    textFaint: Color(0xFFA88798),
    accent: _orchidBright,
    success: Color(0xFF6FD39A),
    restGold: Color(0xFFC9A2E0),
    fail: Color(0xFFFF8A65),
    secondaryAction: Color(0xFFD9A5C2),
    raisedIdle: RaisedMaterial(
      top: Color(0xFF4A1D3C),
      bottom: Color(0xFF3A1530),
      highlight: Color(0x14FFC8E1),
      edge: Color(0xFF6B3459),
      glow: Color(0x00000000),
    ),
    raisedDone: RaisedMaterial(
      top: Color(0xFF341228),
      bottom: Color(0xFF2A0D20),
      highlight: Color(0x0FFFC8E1),
      edge: Color(0xFF4A1D3C),
      glow: Color(0x00000000),
    ),
  ),
  cardRhythm: CardRhythm.focus, // DEV-knappen växlar (Niklas väljer)
  details: ThemeDetails(
    warmupLabel: _muted,
    rule: RuleStyle.solid,
    doneTint: Color(0x00000000),
    historyDate: FontStyle.normal,
    rampColor: _muted,
    round: RoundStyle.flipClock,
  ),
);
