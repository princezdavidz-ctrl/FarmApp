import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/feed_formulations_api.dart';

final feedFormulationsApiProvider = Provider<FeedFormulationsApi>(
  (ref) => FeedFormulationsApi(ref.watch(dioProvider)),
);

final feedFormulationsProvider =
    AsyncNotifierProvider<FeedFormulationsNotifier, List<Map<String, dynamic>>>(
      FeedFormulationsNotifier.new,
    );

class FeedFormulationsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const [];
    return ref.watch(feedFormulationsApiProvider).fetch(farmId);
  }

  Future<void> create(Map<String, dynamic> data) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref.read(feedFormulationsApiProvider).create(farmId, data);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String id) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref.read(feedFormulationsApiProvider).delete(farmId, id);
    ref.invalidateSelf();
    await future;
  }
}
