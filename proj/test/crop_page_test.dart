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
    expect(find.text('Irrigation'), findsOneWidget);
    expect(find.text('Inputs & soil'), findsOneWidget);
    expect(find.text('Pests & diseases'), findsOneWidget);
    expect(find.text('Harvests'), findsOneWidget);
    expect(find.textContaining('No sample figures'), findsOneWidget);
  });
}
