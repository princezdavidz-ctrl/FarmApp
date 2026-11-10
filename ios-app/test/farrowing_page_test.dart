import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/breeding/presentation/pages/farrowing_page.dart';

void main() {
  testWidgets('farrowing page shows outcome tracking and pending litters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FarrowingPage())),
    );

    await tester.pumpAndSettle();

    expect(find.text('Farrowing'), findsOneWidget);
    expect(find.text('Record farrowing outcome'), findsOneWidget);
    expect(find.text('Pending litters'), findsOneWidget);
  });
}
