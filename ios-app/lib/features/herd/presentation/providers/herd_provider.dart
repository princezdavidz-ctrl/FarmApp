import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/herd_api.dart';
import '../../domain/entities/animal.dart';

final herdApiProvider = Provider<HerdApi>(
  (ref) => HerdApi(ref.watch(dioProvider)),
);

final herdProvider = AsyncNotifierProvider<HerdNotifier, List<Animal>>(
  HerdNotifier.new,
);

class HerdNotifier extends AsyncNotifier<List<Animal>> {
  @override
  Future<List<Animal>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return [];
    return ref.watch(herdApiProvider).fetchAnimals(farmId);
  }

  Future<void> createAnimal({
    required String tag,
    required String type,
    required String sex,
    DateTime? birthDate,
    double? weightKg,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    final animal = await ref
        .read(herdApiProvider)
        .createAnimal(
          farmId: farmId,
          tag: tag,
          type: type,
          sex: sex,
          birthDate: birthDate,
          weightKg: weightKg,
          notes: notes,
          imageBytes: imageBytes,
          imageName: imageName,
        );
    final animals = state.valueOrNull ?? const <Animal>[];
    state = AsyncData([animal, ...animals]);
  }

  Future<void> updateAnimal({
    required String animalId,
    String? tag,
    String? status,
    DateTime? birthDate,
    double? weightKg,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(herdApiProvider)
        .updateAnimal(
          farmId: farmId,
          animalId: animalId,
          tag: tag,
          status: status,
          birthDate: birthDate,
          weightKg: weightKg,
          notes: notes,
          imageBytes: imageBytes,
          imageName: imageName,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> archiveAnimal(String animalId) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(herdApiProvider)
        .archiveAnimal(farmId: farmId, animalId: animalId);
    ref.invalidateSelf();
    await future;
  }
}
