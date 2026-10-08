import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/ui/workout/exercise_picker.dart';

/// Öppnar väljaren (en övning) och lämnar svaret i [out].
Future<void> _open(WidgetTester tester, CreateExercise? onCreate, List<ExerciseId?> out) async {
  await tester.pumpWidget(MaterialApp(
    theme: nanosuitThemeData(),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => out.add(await pickExercise(context, title: 'Swap for today', custom: const [], onCreate: onCreate)),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"New exercise" står överst; sökning utan träff blir Create "…" (LT 2026-10-08)', (tester) async {
    final names = <String>[];
    final out = <ExerciseId?>[];
    await _open(tester, (ctx, name) async {
      names.add(name);
      return const Exercise(id: ExerciseId('my_curl'), name: 'My Curl', group: MuscleGroup.arms, measure: Measure.weight, isCustom: true);
    }, out);
    expect(find.text('New exercise'), findsOneWidget, reason: 'syns utan att man söker');
    await tester.enterText(find.byType(TextField), 'Zercher Lunge X');
    await tester.pumpAndSettle();
    expect(find.text('New exercise'), findsNothing);
    await tester.tap(find.text('Create "Zercher Lunge X"'));
    await tester.pumpAndSettle();
    expect(names, ['Zercher Lunge X']);
    expect(out.single, const ExerciseId('my_curl'), reason: 'den nya övningen väljs direkt');
  });

  testWidgets('utan onCreate (inget att skapa med) visas ingen rad', (tester) async {
    await _open(tester, null, []);
    expect(find.text('New exercise'), findsNothing);
  });
}
