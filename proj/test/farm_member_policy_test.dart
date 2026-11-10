import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/settings/data/farm_members_api.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/settings/domain/entities/farm_member.dart';
import 'package:proj/features/settings/presentation/pages/farm_management_page.dart';
import 'package:proj/features/settings/presentation/pages/sections/user_management_section.dart';
import 'package:proj/features/settings/presentation/providers/farm_access_provider.dart';
import 'package:proj/features/settings/presentation/providers/farm_team_provider.dart';
import 'package:proj/security/authorization/permissions.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test(
    'saving member policies maintains their required view permissions',
    () async {
      final member = FarmMember(
        id: 'worker-1',
        name: 'Test Worker',
        email: 'worker@example.com',
        role: UserRole.farmWorker,
        identityNumber: 'worker-1',
      );
      final api = _FakeFarmMembersApi(member);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(_ownerSession())),
          farmMembersApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(farmAccessProvider.future);
      await container
          .read(farmAccessProvider.notifier)
          .togglePermission('worker-1', AppPermission.manageSales, true);

      var permissions = container
          .read(farmAccessProvider)
          .requireValue
          .permissionsFor('worker-1');
      expect(permissions, contains(AppPermission.manageSales));
      expect(permissions, contains(AppPermission.viewSales));
      expect(api.savedPermissions, contains(AppPermission.viewSales));

      await container
          .read(farmAccessProvider.notifier)
          .togglePermission('worker-1', AppPermission.viewSales, false);

      permissions = container
          .read(farmAccessProvider)
          .requireValue
          .permissionsFor('worker-1');
      expect(permissions, isNot(contains(AppPermission.viewSales)));
      expect(permissions, isNot(contains(AppPermission.manageSales)));
    },
  );

  test('removes a member after the farm-owner API request succeeds', () async {
    final member = FarmMember(
      id: 'worker-1',
      name: 'Test Worker',
      email: 'worker@example.com',
      role: UserRole.farmWorker,
      identityNumber: 'worker-1',
    );
    final api = _FakeFarmMembersApi(member);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuthNotifier(_ownerSession())),
        farmMembersApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await container.read(farmAccessProvider.future);
    await container.read(farmAccessProvider.notifier).removeMember('worker-1');

    expect(api.removedMemberId, 'worker-1');
    expect(container.read(farmAccessProvider).requireValue.members, isEmpty);
  });

  testWidgets('shows a member policy list only after expanding that member', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(_ownerSession())),
          farmAccessProvider.overrideWith(_TestFarmAccessNotifier.new),
          farmTeamProvider.overrideWith(_TestFarmTeamNotifier.new),
        ],
        child: const MaterialApp(home: FarmManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    final memberName = find.text('Test Worker');
    await tester.scrollUntilVisible(
      memberName,
      220,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Finances'), findsNothing);
    await tester.tap(memberName);
    await tester.pumpAndSettle();
    expect(find.text('Finances'), findsOneWidget);
  });

  testWidgets('owner can confirm member removal from the actions menu', (
    tester,
  ) async {
    final member = FarmMember(
      id: 'worker-1',
      name: 'Test Worker',
      email: 'worker@example.com',
      role: UserRole.farmWorker,
      identityNumber: 'worker-1',
    );
    final api = _FakeFarmMembersApi(member);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(_ownerSession())),
          farmMembersApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UserManagementSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(api.removedMemberId, 'worker-1');
    expect(find.text('Test Worker'), findsNothing);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.session);

  final Session session;

  @override
  AsyncValue<Session?> build() => AsyncData(session);
}

Session _ownerSession() => Session(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: const User(
    id: 'owner-1',
    name: 'Farm Owner',
    email: 'owner@example.com',
    role: UserRole.farmOwner,
  ),
  farms: const [Farm(id: 'farm-1', name: 'Demo Farm')],
  selectedFarm: const Farm(id: 'farm-1', name: 'Demo Farm'),
);

class _FakeFarmMembersApi extends FarmMembersApi {
  _FakeFarmMembersApi(this.member) : super(Dio());

  final FarmMember member;
  Set<AppPermission>? savedPermissions;
  String? removedMemberId;

  @override
  Future<List<FarmMember>> fetchMembers(String farmId) async => [member];

  @override
  Future<FarmMember> updatePermissions(
    String farmId,
    String userId,
    Set<AppPermission> permissions,
  ) async {
    savedPermissions = permissions;
    return member.copyWith(permissions: permissions);
  }

  @override
  Future<void> removeMember(String farmId, String userId) async {
    removedMemberId = userId;
  }
}

class _TestFarmAccessNotifier extends FarmAccessNotifier {
  @override
  Future<FarmAccessState> build() async => FarmAccessState(
    members: [
      FarmMember(
        id: 'worker-1',
        name: 'Test Worker',
        email: 'worker@example.com',
        role: UserRole.farmWorker,
        identityNumber: 'worker-1',
        permissions: {AppPermission.manageFinance},
      ),
    ],
  );
}

class _TestFarmTeamNotifier extends FarmTeamNotifier {
  @override
  Future<FarmTeamState> build() async => const FarmTeamState();
}
