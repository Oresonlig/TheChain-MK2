// Nano Sakuras kant (Claude Design petal_notch.dart, 2026-10-15): ljusbandet
// ligger INNANFÖR formen (det gamla spåret blurrades utanför och klipptes till
// ett rektangulärt sken) och följer V:et in i spetsen. Ingen skugga.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/active_mark.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/nano_sakura.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';

void main() {
  const size = Size(200, 46);
  final shape = raisedShape(nanoSakura);
  final ring = RimPainter.ring(shape, size);

  test('kanten ligger helt innanför rutan — inget sken utanför formen', () {
    final b = ring.getBounds();
    expect(b.left, greaterThanOrEqualTo(0));
    expect(b.top, greaterThanOrEqualTo(0));
    expect(b.right, lessThanOrEqualTo(size.width));
    expect(b.bottom, lessThanOrEqualTo(size.height));
  });

  test('kanten följer V:et inåt i båda spetsarna (buktar in)', () {
    final notch = (shape as ChevronBorder).notch;
    final cy = size.height / 2;
    // Precis innanför V:ets botten: kant. Ute i klyftan: ingenting.
    expect(ring.contains(Offset(size.width - notch - .7, cy)), isTrue);
    expect(ring.contains(Offset(size.width - notch / 2, cy)), isFalse);
    expect(ring.contains(Offset(notch + .7, cy)), isTrue);
    expect(ring.contains(Offset(notch / 2, cy)), isFalse);
    // Mitt i knappen: ingen kant (knappens eget material syns).
    expect(ring.contains(Offset(size.width / 2, cy)), isFalse);
  });

  test('Sakura: ljusbandet, ingen skugga; Nanosuit oförändrad', () {
    expect(nanoSakura.activeMark, ActiveMark.rimSweep);
    expect(nanoSakura.raisedActive.glow.a, 0);
    expect(nanosuit.activeMark, ActiveMark.tracePulse);
  });

  Widget primary(ChainTheme theme, {required bool enabled}) => MaterialApp(
        theme: buildThemeData(theme),
        home: Center(
          child: PrimaryRim(enabled: enabled, child: Raised(material: theme.raisedActive, child: const Text('START'))),
        ),
      );

  Finder rim() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is RimPainter);

  testWidgets('START/FINISH: stillastående kant i Sakura när knappen är aktiv — aldrig i andra teman', (t) async {
    await t.pumpWidget(primary(nanoSakura, enabled: true));
    expect(rim(), findsOneWidget);
    expect(t.binding.transientCallbackCount, 0, reason: 'ingen rörelse — rörelse = pågående pass');
    await t.pumpWidget(primary(nanoSakura, enabled: false));
    expect(rim(), findsNothing, reason: 'avstängd FINISH: ingen kant');
    await t.pumpWidget(primary(nanosuit, enabled: true));
    await t.pumpAndSettle(); // MaterialApp tonar över mellan teman
    expect(rim(), findsNothing);
  });
}
