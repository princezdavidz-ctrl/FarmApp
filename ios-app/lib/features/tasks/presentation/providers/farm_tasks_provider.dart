import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/farm_task.dart';
import '../../data/farm_tasks_api.dart';

final farmTasksApiProvider = Provider<FarmTasksApi>(
  (ref) => FarmTasksApi(ref.watch(dioProvider)),
);

final farmTasksProvider =
    AsyncNotifierProvider<FarmTasksNotifier, List<FarmTask>>(
      FarmTasksNotifier.new,
    );

class FarmTasksNotifier extends AsyncNotifier<List<FarmTask>> {
  @override
  Future<List<FarmTask>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const [];
    return ref.watch(farmTasksApiProvider).fetch(farmId);
  }

  Future<void> create({
    required String title,
    required String priority,
    required String category,
    String? notes,
    String? assignedTo,
    DateTime? dueAt,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      throw StateError('Select a farm before creating a task.');
    }
    await ref
        .read(farmTasksApiProvider)
        .create(
          farmId,
          title: title,
          priority: priority,
          category: category,
          notes: notes,
          assignedTo: assignedTo,
          dueAt: dueAt,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggle(FarmTask task) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;
    await ref.read(farmTasksApiProvider).update(farmId, task.id, {
      'status': task.isCompleted ? 'open' : 'completed',
    });
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String taskId) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;
    await ref.read(farmTasksApiProvider).delete(farmId, taskId);
    ref.invalidateSelf();
    await future;
  }
}
