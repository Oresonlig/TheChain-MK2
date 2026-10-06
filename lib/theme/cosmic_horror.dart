/// Cosmic Horror — MK2:s version (Niklas 2026-10-06). Biologiskt, främmande:
/// blåsvart botten, mintgrönt liv (grönare än MK1:s teal, så det aldrig kan
/// förväxlas med Nanosuits cyan), blodrött som andra röst (överhoppat, FAIL),
/// bärnsten på vilodagen. Ådror med bioluminiscens i stället för hex-väv,
/// organiska blobbar i stället för chevroner. Cinzel stort, Martian Mono smått
/// (MK1:s Cormorant var för tunn och liten).
///
/// Förbättrat mot MK1: avklarade pass syns (MK1: mörk text på 50 %),
/// ådrorna håller sig till kanterna, och FAIL/överhoppat har en egen färg.
library;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

const _mint = Color(0xFF86D9A8);

const cosmicHorror = ChainTheme(
  name: 'Cosmic Horror',
  background: Color(0xFF03080A),
  backgroundGlow: Color(0xFF0E2A24),
  accent: _mint,
  accentBright: Color(0xFFC8F5DA),
  success: Color(0xFFB6F09C),
  restGold: Color(0xFFD8B878),
  fail: Color(0xFFD0606C), // blodrött, ljust nog för etiketter på mörk botten
  textStrong: Color(0xFFE8F7F0),
  textBody: Color(0xFFB8CCC4),
  textMuted: Color(0xFF86A098),
  textFaint: Color(0xFF6F8B82),
  surface: Color(0xFF0A1A17),
  border: Color(0xFF1A322C),
  borderStrong: Color(0xFF2A4A42),
  glassTop: Color(0x660A1E1A), // 40 %
  glassBottom: Color(0x2E0A1E1A), // 18 %
  glassBlur: 18,
  raisedActive: RaisedMaterial(
    top: Color(0xFF2E6B58),
    bottom: Color(0xFF0E2A22),
    highlight: Color(0x80C8F5DA),
    edge: _mint,
    glow: Color(0x4086D9A8),
  ),
  raisedIdle: RaisedMaterial(
    top: Color(0xFF15342C),
    bottom: Color(0xFF0A1C18),
    highlight: Color(0x3386D9A8),
    edge: Color(0xFF2E5A4C),
    glow: Color(0x00000000),
  ),
  raisedDone: RaisedMaterial(
    top: Color(0xFF0D1E1A),
    bottom: Color(0xFF071210),
    highlight: Color(0x1486D9A8),
    edge: Color(0xFF1E3A33),
    glow: Color(0x00000000),
  ),
  secondaryAction: Color(0xFF6FAF95),
  hexLine: Color(0xFF3A6A5A), // ådrornas färg
  hexEnergy: Color(0xFFC8F5DA), // pulserna
  ambient: Ambient.veins,
  activeMark: ActiveMark.eye,
  cardShape: CardShape.leaf,
  skippedMark: SkippedMark.claw,
  doneMark: DoneMark.scar,
  tabShape: TabShape.blob,
  navMark: NavMark.fang,
  fonts: ThemeType(display: 'Cinzel', text: 'Martian Mono', textWidth: 87.5, textScale: .9),
);
