import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/sales/data/pig_listing.dart';

void main() {
  test('pig listing share text includes buyer-facing listing details', () {
    const listing = PigListing(
      id: 'listing-1',
      title: 'Healthy young sow',
      breed: 'Large White',
      quantity: 2,
      pricePerPig: 45000,
      currency: 'KES',
      status: 'available',
      ageWeeks: 24,
      weightKg: 75,
      location: 'Nakuru',
      description: 'Vaccinated and ready.',
    );

    expect(
      listing.shareText,
      'FarmApp marketplace\n'
      'Healthy young sow\n'
      'Breed: Large White\n'
      'Available: 2\n'
      'Price: KES 45000 per pig\n'
      'Listing ID: listing-1\n'
      'Age: 24 weeks\n'
      'Weight: 75.0 kg\n'
      'Location: Nakuru\n'
      'Vaccinated and ready.',
    );
  });
}
