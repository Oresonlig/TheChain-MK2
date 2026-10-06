import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/arctic.dart';
import 'package:the_chain/theme/floe.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/themes.dart';

void main() {
  test('temaväljaren: Arctic bara i DEV; okänt id → Nanosuit', () {
    expect(themeFor('arctic', devTools: true), same(arctic));
    expect(themeFor('arctic', devTools: false), same(nanosuit), reason: 'stable visar aldrig ett osläppt tema');
    expect(themeFor('finns-inte', devTools: true), same(nanosuit));
    expect(themeFor(null, devTools: true), same(nanosuit));
  });

  test('isflakets frö är stabilt och skiljer flikar åt', () {
    expect(floeSeed('A'), floeSeed('A'));
    expect(floeSeed('A'), isNot(floeSeed('B')));
  });
}
