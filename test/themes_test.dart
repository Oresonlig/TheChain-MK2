import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/active_mark.dart';
import 'package:the_chain/theme/ambient_life.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';
import 'package:the_chain/theme/themes.dart';

void main() {
  test('temaväljaren: okänt eller borttaget id (t.ex. arctic) → Nanosuit', () {
    expect(themeFor('nanosuit', devTools: false), same(nanosuit));
    expect(themeFor('arctic', devTools: true), same(nanosuit), reason: 'Arctic borttaget 2026-10-06');
    expect(themeFor(null, devTools: true), same(nanosuit));
  });

  test('Cosmic Horror: bara i DEV tills Niklas släpper det', () {
    expect(themeFor('cosmic', devTools: true), same(cosmicHorror));
    expect(themeFor('cosmic', devTools: false), same(nanosuit));
  });

  test('blobbens frö är stabilt och skiljer flikar åt', () {
    expect(shapeSeed('A'), shapeSeed('A'));
    expect(shapeSeed('A'), isNot(shapeSeed('B')));
  });

  test('ögat blinkar med slumpad takt, 2,5–9 s, aldrig i jämn rytm', () {
    final r = math.Random(1);
    final gaps = [for (var i = 0; i < 50; i++) nextBlink(r).inMilliseconds];
    expect(gaps.every((g) => g >= 2500 && g <= 9000), isTrue);
    expect(gaps.toSet().length, greaterThan(40), reason: 'inte "var 3:e sekund"');
  });

  test('ådrorna: alltid fullvuxna; LOG sträcker ut dem och de drar sig tillbaka', () {
    AmbientLife.reset();
    expect(AmbientLife.growth(animated: true), AmbientLife.rest);
    expect(AmbientLife.reach(0), 0);
    expect(AmbientLife.reach(1000), 1, reason: 'utsträckt en stund');
    expect(AmbientLife.reach(3500), allOf(greaterThan(0), lessThan(1)), reason: 'på väg tillbaka');
    expect(AmbientLife.reach(AmbientLife.burstLife), 0, reason: 'tillbaka i vila');
    AmbientLife.burst();
    expect(AmbientLife.burstAges, isNotEmpty);
    expect(AmbientLife.growth(animated: false), AmbientLife.rest, reason: 'minska rörelse: ingen utsträckning');
    AmbientLife.reset();
  });
}
