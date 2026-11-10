import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/app/routes/permission_route.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/settings/domain/entities/farm_member.dart';
import 'package:proj/features/settings/presentation/providers/farm_access_provider.dart';
import 'package:proj/security/authorization/permissions.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  testWidgets('hides a feature page when its policy is not granted', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const {}));
    await tester.pumpAndSettle();

    expect(find.text('Restricted feature'), findsNothing);
    expect(
      find.text('The farm owner has not granted access to this feature.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a feature page when its policy is granted', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp({AppPermission.viewReports}));
    await tester.pumpAndSettle();

    expect(find.text('Restricted feature'), findsOneWidget);
    expect(find.text('Feature unavailable'), findsNothing);
  });
}

Widget _testApp(Set<AppPermission> permissions) => ProviderScope(
  overrides: [
    authProvider.overrideWith(
      () => _TestAuthNotifier(
        Session(
          accessToken: 'token',
          refreshToken: 'refresh',
          user: const User(
            id: 'worker-1',
            name: 'Farm Worker',
            email: 'worker@example.com',
            role: UserRole.farmWorker,
          ),
          farms: const [Farm(id: 'farm-1', name: 'Demo Farm')],
          selectedFarm: const Farm(id: 'farm-1', name: 'Demo Farm'),
        ),
      ),
    ),
    farmAccessProvider.overrideWith(() => _TestFarmAccessNotifier(permissions)),
  ],
  child: const MaterialApp(
    home: PermissionRoute(
      permission: AppPermission.viewReports,
      child: Text('Restricted feature'),
    ),
  ),
);

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.session);

  final Session session;

  @override
  AsyncValue<Session?> build() => AsyncData(session);
}

class _TestFarmAccessNotifier extends FarmAccessNotifier {
  _TestFarmAccessNotifier(this.permissions);

  final Set<AppPermission> permissions;

  @override
  Future<FarmAccessState> build() async => FarmAccessState(
    members: [
      FarmMember(
        id: 'worker-1',
        name: 'Farm Worker',
        email: 'worker@example.com',
        role: UserRole.farmWorker,
        identityNumber: 'worker-1',
        permissions: permissions,
      ),
    ],
  );
}
