// Pågående pass: Nanosuits puls rör sig bara när det får röra sig, och bara
// på pågående pass (2026-10-03).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/active_mark.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';

Widget _frame({required bool active, bool animate = true, bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        theme: nanosuitThemeData(),
        home: Center(
          child: ActiveMarkFrame(
            active: active,
            animate: animate,
            child: Raised(material: nanosuit.raisedIdle, child: const Text('B')),
          ),
        ),
      ),
    );

bool _ticking(WidgetTester t) => t.binding.transientCallbackCount > 0;

void main() {
  testWidgets('pågående pass + rörelse på → pulsen går', (t) async {
    await t.pumpWidget(_frame(active: true));
    await t.pump(const Duration(milliseconds: 500));
    expect(_ticking(t), isTrue);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('ambient av eller minska rörelse → stilla (ingen ticker)', (t) async {
    await t.pumpWidget(_frame(active: true, animate: false));
    expect(_ticking(t), isFalse);
    await t.pumpWidget(_frame(active: true, reduceMotion: true));
    expect(_ticking(t), isFalse);
  });

  testWidgets('inte pågående → ingen markering alls', (t) async {
    await t.pumpWidget(_frame(active: false));
    expect(_ticking(t), isFalse);
    expect(
      find.descendant(of: find.byType(ActiveMarkFrame), matching: find.byType(RepaintBoundary)),
      findsNothing,
    );
  });
}
