import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmonia_ai/app.dart';

void main() {
  testWidgets('app boots into onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HarmoniaApp()));
    await tester.pump();

    expect(find.text('Exercise Mode'), findsOneWidget);
  });
}
