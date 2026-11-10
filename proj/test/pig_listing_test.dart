import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/sales/data/pig_listing.dart';

void main() {
  test(
    'pig listing keeps numeric animal IDs and includes them in shared data',
    () {
      final listing = PigListing.fromJson({
        'id': 12,
        'animal_id': 47,
        'title': 'Healthy growers',
        'breed': 'Large White',
        'quantity': 2,
        'price_per_pig': 15000,
        'currency': 'KES',
        'age_weeks': 12,
        'weight_kg': 25.5,
        'location': 'Nakuru',
        'description': 'Vaccinated and ready.',
        'status': 'available',
      });

      expect(listing.animalId, '47');
      expect(listing.shareText, contains('Pig ID: 47'));
      expect(listing.shareText, contains('Listing ID: 12'));
      expect(listing.shareText, contains('Price: KES 15000 per pig'));
      expect(listing.shareText, contains('Weight: 25.5 kg'));
    },
  );
}
