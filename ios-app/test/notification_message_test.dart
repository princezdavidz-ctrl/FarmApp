import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/notifications/data/notifications_api.dart';
import 'package:proj/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test(
    'sending a support message updates observed notification state safely',
    () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          notificationsApiProvider.overrideWithValue(_FakeNotificationsApi()),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(notificationsProvider.future), isEmpty);

      await container
          .read(notificationsProvider.notifier)
          .sendMessage('Hello support');

      final notifications = container.read(notificationsProvider).valueOrNull;
      expect(notifications, hasLength(1));
      expect(notifications!.single.body, 'Hello support');
    },
  );
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

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi() : super(Dio());

  @override
  Future<List<FarmNotification>> fetch(String farmId) async => const [];

  @override
  Future<FarmNotification> sendMessage({
    required String farmId,
    required String message,
  }) async => FarmNotification(
    id: 'sent-1',
    type: 'crm_message_sent',
    title: 'Message sent to Farm App',
    body: message,
    severity: 'success',
    createdAt: DateTime.utc(2026),
  );
}
