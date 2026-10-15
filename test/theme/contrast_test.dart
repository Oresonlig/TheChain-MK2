// Kontrast per tema (WCAG 2.x) — mekaniskt mått i stället för ögonmått
// (CLAUDE.md §5). Varje tema i väljaren måste klara samma golv. Infört med
// första ljusa temat (Nano Sakura, 2026-10-14): där brukar ljusa teman falla
// — rosa på vitt, mörk text på mörk accent.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/themes.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// (namn, förgrund, bakgrund, golv). Texten ligger på glas över
/// bakgrunden eller på [ChainTheme.surface] (blad, dialoger) — båda prövas.
/// [grounds] ersätter dem (mörka kort: kortet blandat över botten).
List<(String, Color, Color, double)> pairs(ChainTheme c, {List<(String, Color)>? grounds}) => [
      for (final (bgName, bg) in grounds ?? [('background', c.background), ('surface', c.surface)]) ...[
        ('textStrong / $bgName', c.textStrong, bg, 7),
        ('textBody / $bgName', c.textBody, bg, 4.5),
        ('textMuted / $bgName', c.textMuted, bg, 4.5),
        ('textFaint / $bgName', c.textFaint, bg, 3),
        ('accent / $bgName', c.accent, bg, 3),
        ('secondaryAction / $bgName', c.secondaryAction, bg, 3),
        ('success / $bgName', c.success, bg, 3),
        ('fail / $bgName', c.fail, bg, 3),
        ('restGold / $bgName', c.restGold, bg, 3),
      ],
      // Text på accentytan (LOG, START, aktiv flik) — båda ändarna av gradienten.
      ('onAccent / raisedActive.top', c.onAccent, c.raisedActive.top, 4.5),
      ('onAccent / raisedActive.bottom', c.onAccent, c.raisedActive.bottom, 4.5),
      // Vanlig flik: bokstaven i accent på vilande yta.
      ('accent / raisedIdle.top', c.accent, c.raisedIdle.top, 3),
      ('textStrong / raisedIdle.bottom', c.textStrong, c.raisedIdle.bottom, 4.5),
    ];

void check(List<(String, Color, Color, double)> list) {
  final fails = <String>[];
  for (final (name, fg, bg, floor) in list) {
    final r = contrast(fg, bg);
    if (r < floor) fails.add('$name ${r.toStringAsFixed(2)} < $floor');
  }
  expect(fails, isEmpty, reason: fails.join('\n'));
}

void main() {
  for (final choice in themeChoices) {
    test('kontrast: ${choice.label}', () => check(pairs(choice.theme)));
  }

  // Mörka kort (Nano Sakura): genomskinliga — kortet blandas med det som
  // ligger bakom. Ljus text → sämsta läget är den LJUSA botten bakom (vågen
  // mörkar bara). Samma golv som allt annat (Niklas valde djup orchid, 2026-10-15).
  for (final choice in themeChoices.where((t) => t.theme.darkCard != null)) {
    test('kontrast: ${choice.label} · mörkt kort (blandat över ljus botten)', () {
      final card = choice.theme.darkCard!;
      final d = choice.theme.darkCardTheme!;
      final base = choice.theme.background;
      check(pairs(d, grounds: [
        ('kortets topp', Color.alphaBlend(card.top, base)),
        ('kortets botten', Color.alphaBlend(card.bottom, base)),
      ]));
    });
  }

  test('ljust tema: Material i ljust läge, mörka teman i mörkt', () {
    for (final choice in themeChoices) {
      final data = buildThemeData(choice.theme);
      expect(data.brightness, choice.theme.isLight ? Brightness.light : Brightness.dark, reason: choice.label);
    }
  });
}
