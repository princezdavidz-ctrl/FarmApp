import 'package:flutter_test/flutter_test.dart';
import 'package:proj/app/routes/route_guard.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test('first-run onboarding routes remain public', () {
    expect(RouteGuard.isPublic('/farm-selection'), isTrue);
    expect(RouteGuard.isPublic('/language'), isTrue);
    expect(RouteGuard.isPublic('/app-tutorial'), isFalse);
  });

  test('logged-out users are redirected to splash from protected pages', () {
    expect(RouteGuard.redirectFor(null, '/home'), '/splash');
  });

  test(
    'logged-in users without a selected farm are sent to farm selection',
    () {
      final session = Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        user: const User(
          id: 'user-1',
          name: 'Test User',
          email: 'user@example.com',
          role: UserRole.farmOwner,
        ),
        farms: const [Farm(id: 'farm-1', name: 'Demo Farm')],
      );

      expect(RouteGuard.redirectFor(session, '/home'), '/farm-selection');
    },
  );

  test('farm managers and workers cannot access the subscription page', () {
    final session = Session(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: const User(
        id: 'user-1',
        name: 'Test User',
        email: 'user@example.com',
        role: UserRole.farmManager,
      ),
      farms: const [Farm(id: 'farm-1', name: 'Demo Farm')],
      selectedFarm: const Farm(id: 'farm-1', name: 'Demo Farm'),
    );

    expect(RouteGuard.redirectFor(session, '/subscription'), '/');
  });

  test('farm owners can access the subscription page', () {
    final session = Session(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: const User(
        id: 'user-1',
        name: 'Test User',
        email: 'user@example.com',
        role: UserRole.farmOwner,
      ),
      farms: const [Farm(id: 'farm-1', name: 'Demo Farm')],
      selectedFarm: const Farm(id: 'farm-1', name: 'Demo Farm'),
    );

    expect(RouteGuard.redirectFor(session, '/subscription'), null);
  });
}
