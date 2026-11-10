import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/feed_api.dart';
import '../../data/feed_schedule_local_data_source.dart';
import '../../data/feed_reminder_service.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

final feedScheduleStorageProvider = Provider<FeedScheduleLocalDataSource>(
  (_) => FeedScheduleLocalDataSource(),
);

final feedScheduleProvider =
    AsyncNotifierProvider<FeedScheduleNotifier, List<FeedScheduleEntry>>(
      FeedScheduleNotifier.new,
    );

final feedReminderServiceProvider = Provider<FeedReminderService>(
  (_) => FeedReminderService(),
);

class FeedScheduleNotifier extends AsyncNotifier<List<FeedScheduleEntry>> {
  @override
  Future<List<FeedScheduleEntry>> build() async {
    final reminders = ref.watch(feedReminderServiceProvider);
    await reminders.initialize();
    final preferences = await ref.watch(userPreferencesProvider.future);
    final session = ref.watch(authProvider).valueOrNull;
    final farm = session?.selectedFarm;
    final user = session?.user;
    if (farm == null || user == null) {
      return FeedScheduleLocalDataSource.defaults;
    }
    final entries = await ref
        .watch(feedScheduleStorageProvider)
        .read(userId: user.id, farmId: farm.id);
    await reminders.sync(
      entries,
      sound: preferences.notificationSound,
      enabled: preferences.notifications['feeding'] ?? true,
    );
    return entries;
  }

  Future<void> saveEntries(List<FeedScheduleEntry> entries) async {
    final session = ref.read(authProvider).valueOrNull;
    final farm = session?.selectedFarm;
    final user = session?.user;
    if (farm == null || user == null) throw StateError('No farm selected.');

    if (entries.length > 20 ||
        entries.map((entry) => entry.id).toSet().length != entries.length) {
      throw ArgumentError(
        'Feeding schedule entries must have unique ids (up to 20).',
      );
    }
    final previous = state.valueOrNull ?? FeedScheduleLocalDataSource.defaults;
    try {
      await ref
          .read(feedScheduleStorageProvider)
          .write(userId: user.id, farmId: farm.id, entries: entries);
      final preferences = await ref.read(userPreferencesProvider.future);
      await ref
          .read(feedReminderServiceProvider)
          .sync(
            entries,
            sound: preferences.notificationSound,
            enabled: preferences.notifications['feeding'] ?? true,
          );
      state = AsyncData(entries);
    } on Object {
      await ref
          .read(feedScheduleStorageProvider)
          .write(userId: user.id, farmId: farm.id, entries: previous);
      final preferences = await ref.read(userPreferencesProvider.future);
      await ref
          .read(feedReminderServiceProvider)
          .sync(
            previous,
            sound: preferences.notificationSound,
            enabled: preferences.notifications['feeding'] ?? true,
          );
      rethrow;
    }
  }

  Future<void> setCompleted(String id, bool completed) async {
    final entries = state.valueOrNull ?? FeedScheduleLocalDataSource.defaults;
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'Unknown feeding time');
    final updated = [...entries];
    updated[index] = updated[index].copyWith(completed: completed);
    await saveEntries(updated);
  }

  Future<void> setReminder(String id, bool enabled) async {
    final entries = state.valueOrNull ?? FeedScheduleLocalDataSource.defaults;
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'Unknown feeding time');
    if (enabled &&
        !await ref.read(feedReminderServiceProvider).requestPermission()) {
      throw const FeedReminderPermissionDenied();
    }
    final updated = [...entries];
    updated[index] = updated[index].copyWith(remindersEnabled: enabled);
    await saveEntries(updated);
  }
}

final feedApiProvider = Provider<FeedApi>(
  (ref) => FeedApi(ref.watch(dioProvider)),
);
final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedSnapshot>(
  FeedNotifier.new,
);

class FeedNotifier extends AsyncNotifier<FeedSnapshot> {
  @override
  Future<FeedSnapshot> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const FeedSnapshot(stock: [], usage: []);
    return ref.watch(feedApiProvider).fetch(farmId);
  }

  Future<void> addStock({
    required String name,
    required double quantity,
    required String unit,
    double? unitCost,
    String? location,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(feedApiProvider)
        .addStock(
          farmId: farmId,
          name: name,
          quantity: quantity,
          unit: unit,
          unitCost: unitCost,
          location: location,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> recordUsage({
    String? stockId,
    required double quantity,
    required String unit,
    required DateTime usedAt,
    String? notes,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(feedApiProvider)
        .recordUsage(
          farmId: farmId,
          stockId: stockId,
          quantity: quantity,
          unit: unit,
          usedAt: usedAt,
          notes: notes,
        );
    ref.invalidateSelf();
    await future;
  }
}
