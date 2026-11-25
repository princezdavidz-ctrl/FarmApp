import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/crops/presentation/pages/crop_page.dart';

void main() {
  testWidgets('crop workspace presents core crop management areas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CropPage()),
    );

    expect(find.text('Crop farming'), findsOneWidget);
    expect(find.text('Fields & plots'), findsOneWidget);
    expect(find.text('Crop cycles'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    for (final label in [
      'Irrigation',
      'Inputs & soil',
      'Pests & diseases',
      'Harvests',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: scrollable,
      );
      expect(find.text(label), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.textContaining('No sample figures'),
      300,
      scrollable: scrollable,
    );
    expect(find.textContaining('No sample figures'), findsOneWidget);
  });
}
