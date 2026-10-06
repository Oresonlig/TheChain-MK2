import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/active_mark.dart';
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

  test('hjärtslaget: två slag (lub starkast), sedan vila', () {
    expect(heartbeat(.08), closeTo(1, .01));
    expect(heartbeat(.26), greaterThan(.6));
    expect(heartbeat(.17), lessThan(heartbeat(.26)));
    expect(heartbeat(.7), lessThan(.01));
  });
}
