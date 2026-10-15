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

// De ihopfällda korten: lätt genomskinlig orchid i stället för nästan svart
// plommon (Niklas 2026-10-15). Platta (topp ≈ botten) — knapparna har gradient
// och spetsar, korten inte: det är så de skiljs åt trots samma färgfamilj.
// Kontrasttestet prövar texten mot kortet blandat över den LJUSA botten
// (sämsta läget). Mer genomskinligt än ~90 % klarar inte texten.

/// Djup orchid #6E1F58, 90 % (Niklas valde den framför accentens orchid
/// 2026-10-15 — den klarade inte kontrastgolvet 7 för kortrubriken).
const sakuraDeepOrchidCard = DarkCard(
  top: Color(0xE67A2462),
  bottom: Color(0xE66E1F58),
  edge: Color(0xFF8E3A78),
  borderStrong: Color(0xFFA0548A),
  textStrong: Color(0xFFFFFFFF),
  textBody: Color(0xFFFCEAF1),
  textMuted: Color(0xFFEBD3DF),
  textFaint: Color(0xFFD2B0C3),
  accent: Color(0xFFFFC2E6),
  success: Color(0xFF8FE3B2),
  restGold: Color(0xFFE2CBF2),
  fail: Color(0xFFFFB9A3),
  secondaryAction: Color(0xFFF0CDE0),
  raisedIdle: RaisedMaterial(
    top: Color(0xFF8A2C70),
    bottom: Color(0xFF7A2462),
    highlight: Color(0x1FFFFFFF),
    edge: Color(0xFFA0548A),
    glow: Color(0x00000000),
  ),
  raisedDone: RaisedMaterial(
    top: Color(0xFF6A1E55),
    bottom: Color(0xFF5E1A4B),
    highlight: Color(0x14FFFFFF),
    edge: Color(0xFF8E3A78),
    glow: Color(0x00000000),
  ),
);

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
    glow: Color(0x00000000), // ingen skugga (Claude Design 2026-10-15: klipps bort i mockupen)
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
  activeMark: ActiveMark.rimSweep, // Claude Designs kant (petal_notch.dart), inte Nanosuits spår
  skippedMark: SkippedMark.cross,
  doneMark: DoneMark.none,
  tabShape: TabShape.petalNotch,
  navMark: NavMark.raised,
  fonts: ThemeType(display: 'Quicksand', text: 'Quicksand', numbers: 'Saira'),
  cardShape: CardShape.square,
  darkCard: sakuraDeepOrchidCard,
  cardRhythm: CardRhythm.focus, // alla ihopfällda fyllda (Niklas 2026-10-15)
  details: ThemeDetails(
    warmupLabel: _muted,
    rule: RuleStyle.solid,
    doneTint: Color(0x00000000),
    historyDate: FontStyle.normal,
    rampColor: _muted,
    round: RoundStyle.flipClock,
  ),
);
