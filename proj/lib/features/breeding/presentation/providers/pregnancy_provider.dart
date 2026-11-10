import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/pregnancy_api.dart';
import '../../domain/entities/pregnancy.dart';

final pregnancyApiProvider = Provider<PregnancyApi>(
  (ref) => PregnancyApi(ref.watch(dioProvider)),
);

final pregnancyProvider =
    AsyncNotifierProvider<PregnancyNotifier, List<Pregnancy>>(
      PregnancyNotifier.new,
    );

class PregnancyNotifier extends AsyncNotifier<List<Pregnancy>> {
  @override
  Future<List<Pregnancy>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return [];
    return ref.watch(pregnancyApiProvider).fetchPregnancies(farmId);
  }

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
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(pregnancyApiProvider)
        .createPregnancy(
          farmId: farmId,
          sowId: sowId,
          matingDate: matingDate,
          boarId: boarId,
          semenUsed: semenUsed,
          confirmationDate: confirmationDate,
          expectedFarrowingDate: expectedFarrowingDate,
          status: status,
          expectedLitterSize: expectedLitterSize,
          notes: notes,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> recordFarrowingOutcome({
    required String pregnancyId,
    required DateTime actualFarrowingDate,
    required int bornAlive,
    int? stillborn,
    int? mummified,
    int? weaned,
    String? notes,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');

    final data = <String, dynamic>{
      'status': 'farrowed',
      'actual_farrowing_date': actualFarrowingDate
          .toIso8601String()
          .split('T')
          .first,
      'born_alive': bornAlive,
      'stillborn': ?stillborn,
      'mummified': ?mummified,
      'weaned': ?weaned,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    await ref
        .read(pregnancyApiProvider)
        .updatePregnancy(farmId: farmId, pregnancyId: pregnancyId, data: data);
    ref.invalidateSelf();
    await future;
  }
}
