// Renderar förhandsvisningen till en bild (golden) med riktiga typsnittet, så
// att utseendet kan granskas utan telefon. Kör: `node tool/flutter.mjs test
// test/golden --run-skipped --update-goldens` → test/golden/goldens/preview.png
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/main.dart';

Future<void> _loadSaira() async {
  final loader = FontLoader('Saira')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Saira-Variable.ttf').readAsBytesSync())))
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Saira-Italic-Variable.ttf').readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets('Nanosuit preview', (tester) async {
    await _loadSaira();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(
        size: Size(411.4, 891.4),
        devicePixelRatio: 2.625,
        padding: EdgeInsets.only(top: 36, bottom: 24),
        disableAnimations: true,
      ),
      child: TheChainApp(),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(TheChainApp), matchesGoldenFile('goldens/preview.png'));
  });
}
