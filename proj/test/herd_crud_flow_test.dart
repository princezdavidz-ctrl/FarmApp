import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/health/presentation/providers/health_providers.dart';
import 'package:proj/features/herd/data/herd_api.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/pages/herd_page.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  testWidgets('adding a pig persists and refreshes the farm herd', (
    WidgetTester tester,
  ) async {
    final api = _FakeHerdApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          herdApiProvider.overrideWithValue(api),
          healthOverviewProvider.overrideWith((ref) async => {'vaccinated': 0}),
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
    expect(find.text('Add pig details'), findsOneWidget);
    expect(find.text('Pig name (optional)'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'PIG-NEW');
    await tester.enterText(fields.at(1), 'Daisy');
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(2), '45.5');
    await tester.tap(find.text('Add pig'));
    await tester.pumpAndSettle();

    expect(api.createdTags, ['PIG-NEW']);
    expect(api.createdWeights, [45.5]);
    expect(api.createdNames, ['Daisy']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered female and piglet gaps show addable detail slots', (
    WidgetTester tester,
  ) async {
    final api = _FakeHerdApi(
      animals: [
        const Animal(
          id: 'animal-1',
          tag: 'PIG-001',
          type: 'sow',
          sex: 'female',
          status: 'active',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => _TestAuthNotifier(
              farm: const Farm(
                id: 'farm-1',
                name: 'Test Farm',
                motherPigCount: 2,
                registeredPigletCount: 1,
              ),
            ),
          ),
          herdApiProvider.overrideWithValue(api),
          healthOverviewProvider.overrideWith((ref) async => {'vaccinated': 0}),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HerdPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Complete registered pig details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Female pig 1'), findsOneWidget);
    expect(find.text('Piglet 1'), findsOneWidget);
    expect(find.text('Suggested tag: PIG-002'), findsOneWidget);
    expect(find.text('Suggested tag: PIG-003'), findsOneWidget);

    final addPigletDetails = find.text('Add details').last;
    await tester.ensureVisible(addPigletDetails);
    await tester.tap(addPigletDetails);
    await tester.pumpAndSettle();
    expect(find.text('Add pig details'), findsOneWidget);
    expect(find.text('PIG-003'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .initialValue,
      'piglet',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-fill creates uniquely tagged registered pigs', (
    WidgetTester tester,
  ) async {
    final api = _FakeHerdApi(
      animals: [
        const Animal(
          id: 'animal-1',
          tag: 'PIG-001',
          type: 'sow',
          sex: 'female',
          status: 'active',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => _TestAuthNotifier(
              farm: const Farm(
                id: 'farm-1',
                name: 'Test Farm',
                motherPigCount: 2,
                registeredPigletCount: 1,
              ),
            ),
          ),
          herdApiProvider.overrideWithValue(api),
          healthOverviewProvider.overrideWith((ref) async => {'vaccinated': 0}),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HerdPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto-fill herd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create 2 pigs'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.createdTags, ['PIG-002', 'PIG-003']);
    expect(api.createdTypes, ['sow', 'piglet']);
    expect(api.createdSexes, ['female', 'unknown']);
    expect(find.text('Created 2 pig records.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a pig exposes its photo replacement control', (
    WidgetTester tester,
  ) async {
    final api = _FakeHerdApi(
      animals: [
        const Animal(
          id: 'animal-1',
          tag: 'PIG-1',
          type: 'sow',
          sex: 'female',
          status: 'active',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          herdApiProvider.overrideWithValue(api),
          healthOverviewProvider.overrideWith((ref) async => {'vaccinated': 0}),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HerdPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Change photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('updating an animal applies the server-returned photo URL', () async {
    final api = _FakeHerdApi(
      animals: [
        const Animal(
          id: 'animal-1',
          tag: 'PIG-1',
          type: 'sow',
          sex: 'female',
          status: 'active',
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuthNotifier.new),
        herdApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await container.read(herdProvider.future);
    final imageBytes = Uint8List.fromList([1, 2, 3]);
    await container
        .read(herdProvider.notifier)
        .updateAnimal(
          animalId: 'animal-1',
          imageBytes: imageBytes,
          imageName: 'replacement.jpg',
        );

    expect(api.updatedImageBytes, imageBytes);
    expect(api.updatedImageName, 'replacement.jpg');
    expect(
      container.read(herdProvider).valueOrNull?.single.imageUrl,
      'https://example.com/replacement.jpg',
    );
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier({this.farm = const Farm(id: 'farm-1', name: 'Test Farm')});

  final Farm farm;

  @override
  AsyncValue<Session?> build() => AsyncData(
    Session(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: const User(
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        role: UserRole.farmOwner,
      ),
      farms: [farm],
      selectedFarm: farm,
    ),
  );
}

class _FakeHerdApi extends HerdApi {
  _FakeHerdApi({List<Animal> animals = const []})
    : _animals = List.of(animals),
      super(Dio());

  final List<Animal> _animals;
  final List<String> createdTags = [];
  final List<double?> createdWeights = [];
  final List<String?> createdNames = [];
  final List<String> createdTypes = [];
  final List<String> createdSexes = [];
  Uint8List? updatedImageBytes;
  String? updatedImageName;
  var _nextId = 1;

  @override
  Future<List<Animal>> fetchAnimals(String farmId) async => List.of(_animals);

  @override
  Future<Animal> createAnimal({
    required String farmId,
    required String tag,
    required String type,
    required String sex,
    String? status,
    String? name,
    DateTime? birthDate,
    double? weightKg,
    bool isPregnant = false,
    DateTime? lastDewormedAt,
    DateTime? lastVaccinatedAt,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    createdTags.add(tag);
    createdTypes.add(type);
    createdSexes.add(sex);
    createdWeights.add(weightKg);
    createdNames.add(name);
    final animal = Animal(
      id: 'animal-${_nextId++}',
      tag: tag,
      type: type,
      sex: sex,
      status: status ?? 'active',
      name: name,
      birthDate: birthDate,
      weightKg: weightKg,
      isPregnant: isPregnant,
      lastDewormedAt: lastDewormedAt,
      lastVaccinatedAt: lastVaccinatedAt,
      notes: notes,
    );
    _animals.add(animal);
    return animal;
  }

  @override
  Future<Animal> updateAnimal({
    required String farmId,
    required String animalId,
    String? tag,
    String? status,
    String? name,
    String? sex,
    DateTime? birthDate,
    double? weightKg,
    bool? isPregnant,
    DateTime? lastDewormedAt,
    DateTime? lastVaccinatedAt,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    updatedImageBytes = imageBytes;
    updatedImageName = imageName;
    final index = _animals.indexWhere((animal) => animal.id == animalId);
    final updated = Animal(
      id: animalId,
      tag: tag ?? _animals[index].tag,
      type: _animals[index].type,
      sex: sex ?? _animals[index].sex,
      status: status ?? _animals[index].status,
      name: name ?? _animals[index].name,
      birthDate: birthDate ?? _animals[index].birthDate,
      weightKg: weightKg ?? _animals[index].weightKg,
      isPregnant: isPregnant ?? _animals[index].isPregnant,
      lastDewormedAt: lastDewormedAt ?? _animals[index].lastDewormedAt,
      lastVaccinatedAt: lastVaccinatedAt ?? _animals[index].lastVaccinatedAt,
      notes: notes ?? _animals[index].notes,
      imageUrl: imageBytes == null
          ? _animals[index].imageUrl
          : 'https://example.com/replacement.jpg',
    );
    _animals[index] = updated;
    return updated;
  }
}
