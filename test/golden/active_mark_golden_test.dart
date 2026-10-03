// Nanosuits puls runt pågående pass, fångad mitt i varvet (två lägen).
// Kör: `node tool/flutter.mjs test test/golden --run-skipped --update-goldens`
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/active_mark.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';

void main() {
  testWidgets('puls runt pågående pass', (tester) async {
    await (FontLoader('Saira')
          ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Saira-Variable.ttf').readAsBytesSync()))))
        .load();
    tester.view.physicalSize = const Size(1080, 360);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    Widget tab(String l, RaisedMaterial m, {bool active = false, String? name}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActiveMarkFrame(
            active: active,
            child: Raised(
              material: m,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Builder(builder: (context) {
                final s = Theme.of(context).textTheme.labelLarge!.copyWith(color: context.chain.textStrong);
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l, style: s.copyWith(fontSize: 20)),
                  if (name != null) ...[const SizedBox(width: 10), Text(name, style: s)],
                  if (active) ...[
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: context.chain.success, shape: BoxShape.circle)),
                  ],
                ]);
              }),
            ),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      theme: nanosuitThemeData(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: nanosuit.background,
        body: Center(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            tab('A', nanosuit.raisedDone),
            tab('B', nanosuit.raisedActive, active: true, name: 'BACK HEAVY'),
            tab('C', nanosuit.raisedIdle),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/active_mark_a.png'));
    await tester.pump(const Duration(milliseconds: 1500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/active_mark_b.png'));
  });
}
