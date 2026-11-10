import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/sales/data/pig_listing.dart';
import 'package:proj/features/sales/data/pig_marketplace_api.dart';
import 'package:proj/features/sales/presentation/pages/pig_marketplace_tabs.dart';
import 'package:proj/features/sales/presentation/providers/pig_marketplace_provider.dart';

void main() {
  test('marketplace API resolves a posted image URL for buyers', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 'listing-1',
                      'title': 'Healthy weaner',
                      'breed': 'Large White',
                      'quantity': 1,
                      'price_per_pig': 18000,
                      'currency': 'KES',
                      'status': 'available',
                      'image_url':
                          'http://localhost:8000/storage/animal-images/pig.jpg',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

    final listings = await PigMarketplaceApi(dio).fetchFarmListings('farm-1');

    expect(
      listings.single.imageUrl,
      'https://api.example.com/storage/animal-images/pig.jpg',
    );
  });

  testWidgets('buyers tab renders the posted listing image', (tester) async {
    const imageUrl = 'https://api.example.com/storage/animal-images/pig.jpg';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          pigMarketplaceProvider.overrideWith(_TestPigMarketplaceNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: ForBuyersTab())),
      ),
    );
    await tester.pump();

    expect(find.text('Healthy weaner'), findsOneWidget);
    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is NetworkImage &&
          (widget.image as NetworkImage).url == imageUrl,
    );
    expect(imageFinder, findsOneWidget);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<Session?> build() => const AsyncData(null);
}

class _TestPigMarketplaceNotifier extends PigMarketplaceNotifier {
  @override
  Future<List<PigListing>> build() async => const [
    PigListing(
      id: 'listing-1',
      title: 'Healthy weaner',
      breed: 'Large White',
      quantity: 1,
      pricePerPig: 18000,
      currency: 'KES',
      status: 'available',
      imageUrl: 'https://api.example.com/storage/animal-images/pig.jpg',
    ),
  ];
}
