import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moneyback/main.dart';
import 'package:moneyback/providers/case_state.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CaseState(),
        child: const MoneyBackApp(),
      ),
    );
  });
}
