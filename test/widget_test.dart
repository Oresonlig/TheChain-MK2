// Heter widget_test.dart med avsikt: `flutter create .` i CI hoppar då över
// sin egen mall-fil (som refererar till en MyApp som inte finns).
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/main.dart';

void main() {
  testWidgets('F0 placeholder renders the app name', (tester) async {
    await tester.pumpWidget(const TheChainApp());
    expect(find.text('THE CHAIN'), findsOneWidget);
    expect(find.text('MK2 · F0'), findsOneWidget);
  });
}
