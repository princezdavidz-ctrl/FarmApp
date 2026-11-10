import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pig_world_suppliers/main.dart';

void main() {
  testWidgets('welcome page shows the branded animal supplier entry points', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(home: WelcomePage(controller: controller)),
    );

    expect(find.text('Supplier'), findsOneWidget);
    expect(find.text('Register as a supplier'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets(
    'application form asks for supplier business verification details',
    (tester) async {
      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(home: ApplicationPage(controller: controller)),
      );

      expect(find.text('Business registration number'), findsOneWidget);
      expect(find.text('Business or shop name'), findsOneWidget);
      expect(find.text('Submit for verification'), findsOneWidget);
    },
  );

  testWidgets('supplier can enter animal product catalogue details', (
    tester,
  ) async {
    final controller = AppController();
    controller.openProductForm();
    await tester.pumpWidget(
      MaterialApp(home: ProductFormPage(controller: controller)),
    );

    expect(find.text('Add a product'), findsOneWidget);
    expect(find.text('Product name'), findsOneWidget);
    expect(
      find.text('Category (feed, medicine, equipment...)'),
      findsOneWidget,
    );
    expect(find.text('Publish product listing'), findsOneWidget);
  });
}
