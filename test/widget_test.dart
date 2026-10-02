import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/main.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/hex_field.dart';

void main() {
  testWidgets('Nanosuit-förhandsvisningen renderar med temat och SafeArea', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true, padding: EdgeInsets.only(top: 40)),
      child: TheChainApp(),
    ));
    expect(find.text('CHAIN'), findsOneWidget);
    expect(find.text('Dead Hang'), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    final ctx = tester.element(find.text('Dead Hang'));
    expect(ctx.chain.name, 'Nanosuit');
  });

  test('hex-väven: layout fyller ytan och vågor lever och dör', () {
    final m = HexFieldModel();
    m.layout(const Size(400, 800));
    expect(m.hexes.length, greaterThan(500));
    for (var i = 0; i < 400; i++) {
      m.step();
    }
    expect(m.frame, 400);
    expect(m.waves.length, lessThan(12)); // gamla vågor städas bort
  });
}
