/// Temaväljaren: id (sparas i UserSettings.theme) → tema. Ett nytt tema är
/// bara DEV ([ThemeChoice.devOnly]) tills Niklas släpper det.
library;

import 'package:flutter/material.dart';

import 'chain_theme.dart';
import 'cosmic_horror.dart';
import 'nanosuit.dart';

class ThemeChoice {
  const ThemeChoice(this.id, this.label, this.theme, {this.devOnly = false});
  final String id;
  final String label;
  final ChainTheme theme;
  final bool devOnly;
}

const themeChoices = [
  ThemeChoice('nanosuit', 'NANOSUIT', nanosuit),
  ThemeChoice('cosmic', 'COSMIC HORROR', cosmicHorror), // släppt 2026-10-08
  // Arctic: borttaget 2026-10-06 (Niklas: för likt Nanosuit) — görs om i Claude Design.
];

/// Okänt id, eller ett DEV-tema i ett stable-bygge → Nanosuit.
ChainTheme themeFor(String? id, {required bool devTools}) {
  for (final t in themeChoices) {
    if (t.id == id && (devTools || !t.devOnly)) return t.theme;
  }
  return nanosuit;
}

final _cache = <ChainTheme, ThemeData>{};

/// ThemeData byggs en gång per tema (MaterialApp ritas om ofta).
ThemeData themeDataFor(ChainTheme c) => _cache.putIfAbsent(c, () => buildThemeData(c));
