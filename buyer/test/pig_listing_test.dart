import 'package:flutter_test/flutter_test.dart';
import 'package:pigworld_buyer/main.dart';

void main() {
  final listings = [
    PigListing.fromJson({
      'id': '1',
      'title': 'Weaner A',
      'breed': 'Large White',
      'quantity': 2,
      'price_per_pig': 24000,
      'weight_kg': 30,
      'farm_name': 'North Farm',
      'created_at': '2026-10-07T12:00:00Z',
    }),
    PigListing.fromJson({
      'id': '2',
      'title': 'Gilt B',
      'breed': 'Landrace',
      'quantity': 1,
      'price_per_pig': 18000,
      'weight_kg': 70,
      'farm_name': 'South Farm',
      'created_at': '2026-10-08T12:00:00Z',
    }),
  ];

  test('parses a marketplace listing for buyer display', () {
    final listing = PigListing.fromJson({
      'id': 7,
      'title': 'Healthy weaners',
      'breed': 'Large White',
      'quantity': 6,
      'price_per_pig': '18000.00',
      'currency': 'KES',
      'farm_name': 'Green Acres',
      'farm_location': 'Nakuru',
      'age_weeks': 10,
      'weight_kg': '18.50',
      'image_url': 'https://api.example.test/storage/animal-images/pig.jpg',
      'created_at': '2026-10-07T12:00:00Z',
    });

    expect(listing.id, '7');
    expect(listing.breed, 'Large White');
    expect(listing.quantity, 6);
    expect(listing.pricePerPig, 18000);
    expect(listing.location, 'Nakuru');
    expect(listing.weightKg, 18.5);
    expect(
      listing.imageUrl,
      'https://api.example.test/storage/animal-images/pig.jpg',
    );
    expect(listing.createdAt, DateTime.utc(2026, 10, 7, 12));
    expect(listing.searchableText, contains('green acres'));
  });

  test('parses delivery request status and farm information', () {
    final delivery = BuyerDelivery.fromJson({
      'id': '12',
      'buyer_name': 'Amina',
      'phone': '+254700000005',
      'quantity': 2,
      'status': 'accepted',
      'message': 'Arrange delivery',
      'created_at': '2026-10-08T08:00:00+00:00',
      'listing': {
        'title': 'Healthy weaners',
        'breed': 'Large White',
        'farm_name': 'Green Acres',
        'farm_location': 'Nakuru',
        'price_per_pig': '18000.00',
        'currency': 'KES',
        'weight_kg': '18.50',
        'age_weeks': 10,
        'image_url': 'https://api.example.test/storage/pig.jpg',
      },
    });

    expect(delivery.status, 'accepted');
    expect(delivery.listingTitle, 'Healthy weaners');
    expect(delivery.farmName, 'Green Acres');
    expect(delivery.quantity, 2);
    expect(delivery.pricePerPig, 18000);
    expect(delivery.weightKg, 18.5);
    expect(delivery.ageWeeks, 10);
    expect(delivery.imageUrl, 'https://api.example.test/storage/pig.jpg');
  });

  test('filters listings by search and breed and sorts by price', () {
    final results = filterAndSortListings(
      listings,
      search: 'farm',
      breed: 'Large White',
      sortOrder: 'price_low',
    );

    expect(results.map((listing) => listing.id), ['1']);
  });

  test('filters listings by location, currency, price, age and weight', () {
    final results = filterAndSortListings(
      [
        PigListing.fromJson({
          'id': '1',
          'title': 'Healthy weaners',
          'breed': 'Large White',
          'quantity': 4,
          'price_per_pig': 24000,
          'currency': 'KES',
          'farm_name': 'North Farm',
          'farm_location': 'Nakuru',
          'age_weeks': 10,
          'weight_kg': 18,
        }),
        ...listings,
      ],
      filters: const MarketplaceFilters(
        location: 'nakuru',
        currency: 'KES',
        minPrice: 20000,
        maxPrice: 25000,
        minAgeWeeks: 8,
        maxAgeWeeks: 12,
        minWeightKg: 15,
        maxWeightKg: 20,
      ),
    );

    expect(results.map((listing) => listing.id), ['1']);
  });

  test('requires known listing values to satisfy age and weight filters', () {
    final results = filterAndSortListings(
      listings,
      filters: const MarketplaceFilters(minAgeWeeks: 1, minWeightKg: 1),
    );

    expect(results, isEmpty);
  });

  test('sorts listings by newest, price and weight', () {
    expect(filterAndSortListings(listings).map((listing) => listing.id), [
      '2',
      '1',
    ]);
    expect(
      filterAndSortListings(
        listings,
        sortOrder: 'price_low',
      ).map((listing) => listing.id),
      ['2', '1'],
    );
    expect(
      filterAndSortListings(
        listings,
        sortOrder: 'weight_high',
      ).map((listing) => listing.id),
      ['2', '1'],
    );
  });
}
