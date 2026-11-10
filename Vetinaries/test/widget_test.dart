import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pig_world_veterinaries/main.dart';

void main() {
  testWidgets('welcome page shows the branded veterinarian entry points', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(home: WelcomePage(controller: controller)),
    );

    expect(find.text('Veterinarian'), findsOneWidget);
    expect(find.text('Apply as a veterinarian'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('application form asks for veterinary verification details', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(home: ApplicationPage(controller: controller)),
    );

    expect(find.text('Veterinary license number'), findsOneWidget);
    expect(find.text('Clinic or practice name'), findsOneWidget);
    expect(find.text('Submit for verification'), findsOneWidget);
  });
}
