import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/pig_listing.dart';
import '../../data/pig_marketplace_api.dart';

final pigMarketplaceApiProvider = Provider<PigMarketplaceApi>(
  (ref) => PigMarketplaceApi(ref.watch(dioProvider)),
);

final pigMarketplaceProvider =
    AsyncNotifierProvider<PigMarketplaceNotifier, List<PigListing>>(
      PigMarketplaceNotifier.new,
    );

class PigMarketplaceNotifier extends AsyncNotifier<List<PigListing>> {
  @override
  Future<List<PigListing>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const [];
    return ref.watch(pigMarketplaceApiProvider).fetchFarmListings(farmId);
  }

  Future<void> createListing({
    required String title,
    required String breed,
    required int quantity,
    required double pricePerPig,
    required String currency,
    String? animalId,
    int? ageWeeks,
    double? weightKg,
    String? location,
    String? description,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref.read(pigMarketplaceApiProvider).createListing(farmId, {
      'title': title,
      'breed': breed,
      'quantity': quantity,
      'price_per_pig': pricePerPig,
      'currency': currency,
      'animal_id': ?animalId,
      'age_weeks': ?ageWeeks,
      'weight_kg': ?weightKg,
      if (location != null && location.isNotEmpty) 'location': location,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateListingStatus(String listingId, String status) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref
        .read(pigMarketplaceApiProvider)
        .updateListingStatus(farmId, listingId, status);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateInquiryStatus(
    String listingId,
    String inquiryId,
    String status,
  ) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref
        .read(pigMarketplaceApiProvider)
        .updateInquiryStatus(farmId, listingId, inquiryId, status);
    ref.invalidateSelf();
    await future;
  }
}
