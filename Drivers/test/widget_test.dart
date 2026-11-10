import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pig_world_drivers/main.dart';

void main() {
  testWidgets('welcome page offers driver registration and sign in', (
    tester,
  ) async {
    final controller = DriverController();
    await tester.pumpWidget(
      MaterialApp(home: WelcomePage(controller: controller)),
    );

    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Register as a driver'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('registration requests transport and vehicle verification', (
    tester,
  ) async {
    final controller = DriverController();
    await tester.pumpWidget(
      MaterialApp(home: RegistrationPage(controller: controller)),
    );

    expect(find.text('Driver licence number'), findsOneWidget);
    expect(find.text('Herd / livestock transport'), findsOneWidget);
    expect(find.text('Animal supplies transport'), findsOneWidget);
    expect(find.text('Submit for verification'), findsOneWidget);
  });

  testWidgets('driver home presents a map and availability control', (
    tester,
  ) async {
    final controller = DriverController()
      ..driver = {
        'name': 'Test Driver',
        'status': 'approved',
        'service_types': ['herd', 'supplies'],
      };
    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(find.text('You are offline'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
