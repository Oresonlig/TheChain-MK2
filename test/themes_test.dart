import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/themes.dart';

void main() {
  test('temaväljaren: okänt eller borttaget id (t.ex. arctic) → Nanosuit', () {
    expect(themeFor('nanosuit', devTools: false), same(nanosuit));
    expect(themeFor('arctic', devTools: true), same(nanosuit), reason: 'Arctic borttaget 2026-10-06');
    expect(themeFor(null, devTools: true), same(nanosuit));
  });
}
