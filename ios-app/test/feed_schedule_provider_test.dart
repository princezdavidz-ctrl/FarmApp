import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/feed/data/feed_reminder_service.dart';
import 'package:proj/features/feed/data/feed_schedule_local_data_source.dart';
import 'package:proj/features/feed/presentation/providers/feed_provider.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test(
    'schedule changes persist and denied reminder permission is surfaced',
    () async {
      final storage = _MemoryFeedScheduleStorage();
      final reminders = _FakeFeedReminderService();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          feedScheduleStorageProvider.overrideWithValue(storage),
          feedReminderServiceProvider.overrideWithValue(reminders),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(feedScheduleProvider.future);
      expect(initial, FeedScheduleLocalDataSource.defaults);

      await container
          .read(feedScheduleProvider.notifier)
          .setCompleted('morning', true);
      expect(storage.entries[0].completed, isTrue);

      await container
          .read(feedScheduleProvider.notifier)
          .setReminder('midday', true);
      expect(storage.entries[1].remindersEnabled, isTrue);
      expect(reminders.syncedEntries.last[1].remindersEnabled, isTrue);

      reminders.permissionGranted = false;
      await expectLater(
        container
            .read(feedScheduleProvider.notifier)
            .setReminder('evening', true),
        throwsA(isA<FeedReminderPermissionDenied>()),
      );
      expect(storage.entries[2].remindersEnabled, isFalse);
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

class _MemoryFeedScheduleStorage extends FeedScheduleLocalDataSource {
  List<FeedScheduleEntry> entries = FeedScheduleLocalDataSource.defaults;

  @override
  Future<List<FeedScheduleEntry>> read({
    required String userId,
    required String farmId,
  }) async => entries;

  @override
  Future<void> write({
    required String userId,
    required String farmId,
    required List<FeedScheduleEntry> entries,
  }) async {
    this.entries = List.of(entries);
  }
}

class _FakeFeedReminderService extends FeedReminderService {
  bool permissionGranted = true;
  final syncedEntries = <List<FeedScheduleEntry>>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> sync(List<FeedScheduleEntry> entries) async {
    syncedEntries.add(List.of(entries));
  }
}
