import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/theme/hex_field.dart';
import 'package:the_chain/theme/nanosuit.dart';

void main() {
  for (final theme in [nanosuit, cosmicHorror]) {
  testWidgets('${theme.name}: ambient av → på: bakgrunden rör sig igen (fryste 2026-10-03)', (tester) async {
    final model = HexFieldModel();
    Widget bg(bool on) => Directionality(
          textDirection: TextDirection.ltr,
          child: HexFieldBackground(theme: theme, enabled: on, model: model),
        );

    await tester.pumpWidget(bg(true));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(model.frame, greaterThan(30));

    await tester.pumpWidget(bg(false));
    final stopped = model.frame;
    await tester.pump(const Duration(seconds: 1));
    expect(model.frame, stopped, reason: 'av = stilla');

    await tester.pumpWidget(bg(true));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(model.frame, greaterThan(stopped + 10), reason: 'på igen = rör sig');
  });
  }
}
