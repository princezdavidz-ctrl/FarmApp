import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/breeding/domain/entities/pregnancy.dart';
import 'package:proj/features/breeding/presentation/pages/pregnancy_page.dart';
import 'package:proj/features/breeding/presentation/providers/pregnancy_provider.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/pages/herd_page.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  testWidgets('female pig insemination selection uses its Pig ID', (
    tester,
  ) async {
    _TestPregnancyNotifier.createdSowId = null;
    _TestPregnancyNotifier.items = const [];
    await tester.pumpWidget(_testApp(const PregnancyPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('FEMALE-42 · Pig ID 42'), findsNWidgets(2));
    expect(find.text('MALE-43 · Pig ID 43'), findsNothing);
    await tester.tap(find.text('FEMALE-42 · Pig ID 42').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Save (due'));
    await tester.tap(find.textContaining('Save (due'));
    await tester.pumpAndSettle();

    expect(_TestPregnancyNotifier.createdSowId, '42');
  });

  testWidgets('female Herd details show their pregnancy report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _TestPregnancyNotifier.items = [
      Pregnancy(
        id: 'pregnancy-1',
        sowId: '42',
        sowTag: 'FEMALE-42',
        matingDate: DateTime(2026, 1, 10),
        expectedFarrowingDate: DateTime(2026, 5, 4),
        status: 'confirmed',
      ),
      Pregnancy(
        id: 'pregnancy-2',
        sowId: '43',
        sowTag: 'MALE-43',
        matingDate: DateTime(2026, 1, 10),
        expectedFarrowingDate: DateTime(2026, 5, 4),
        status: 'suspected',
      ),
    ];
    await tester.pumpWidget(_testApp(const HerdPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pregnancy report'));
    expect(find.text('Pregnancy report'), findsOneWidget);
    expect(find.text('Confirmed · inseminated 10/1/2026'), findsOneWidget);
    expect(find.textContaining('MALE-43'), findsNothing);
  });
}

Widget _testApp(Widget child) => ProviderScope(
  overrides: [
    authProvider.overrideWith(_TestAuthNotifier.new),
    herdProvider.overrideWith(_TestHerdNotifier.new),
    pregnancyProvider.overrideWith(_TestPregnancyNotifier.new),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

final _farm = const Farm(id: 'farm-1', name: 'Test Farm');
final _session = Session(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: const User(
    id: 'owner-1',
    name: 'Farm Owner',
    email: 'owner@example.com',
    role: UserRole.farmOwner,
  ),
  farms: [_farm],
  selectedFarm: _farm,
);

class _TestAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<Session?> build() => AsyncData(_session);
}

class _TestHerdNotifier extends HerdNotifier {
  @override
  Future<List<Animal>> build() async => const [
    Animal(
      id: '42',
      tag: 'FEMALE-42',
      type: 'sow',
      sex: 'female',
      status: 'active',
    ),
    Animal(
      id: '43',
      tag: 'MALE-43',
      type: 'boar',
      sex: 'male',
      status: 'active',
    ),
  ];
}

class _TestPregnancyNotifier extends PregnancyNotifier {
  static String? createdSowId;
  static List<Pregnancy> items = const [];

  @override
  Future<List<Pregnancy>> build() async => items;

  @override
  Future<void> create({
    required String sowId,
    required DateTime matingDate,
    String? boarId,
    String? semenUsed,
    DateTime? confirmationDate,
    DateTime? expectedFarrowingDate,
    String status = 'suspected',
    int? expectedLitterSize,
    String? notes,
  }) async {
    createdSowId = sowId;
  }
}
