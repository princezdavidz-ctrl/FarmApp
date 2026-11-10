import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/herd/data/herd_api.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/pages/herd_page.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  testWidgets('entering and saving pig details does not use disposed inputs', (
    WidgetTester tester,
  ) async {
    final api = _FakeHerdApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          herdApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HerdPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Pig'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'PIG-NEW');
    await tester.enterText(fields.at(1), '45.5');
    await tester.tap(find.text('Add pig').last);
    await tester.pumpAndSettle();

    expect(api.createdTags, ['PIG-NEW']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('herd page does not show the herd status summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HerdPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Herd status'), findsNothing);
    expect(find.text('Pregnant'), findsNothing);
    expect(find.text('Vaccinated'), findsNothing);
    expect(find.textContaining('Setup saved:'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<Session?> build() => const AsyncData(
    Session(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: User(
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        role: UserRole.farmOwner,
      ),
      farms: [Farm(id: 'farm-1', name: 'Test Farm')],
      selectedFarm: Farm(id: 'farm-1', name: 'Test Farm'),
    ),
  );
}

class _FakeHerdApi extends HerdApi {
  _FakeHerdApi() : super(Dio());

  final createdTags = <String>[];

  @override
  Future<List<Animal>> fetchAnimals(String farmId) async => [];

  @override
  Future<Animal> createAnimal({
    required String farmId,
    required String tag,
    required String type,
    required String sex,
    DateTime? birthDate,
    double? weightKg,
    bool isPregnant = false,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    createdTags.add(tag);
    return Animal(
      id: 'animal-1',
      tag: tag,
      type: type,
      sex: sex,
      status: 'active',
      birthDate: birthDate,
      weightKg: weightKg,
      notes: notes,
    );
  }
}
