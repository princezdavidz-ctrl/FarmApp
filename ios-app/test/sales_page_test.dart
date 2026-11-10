import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/reports/data/reports_api.dart';
import 'package:proj/features/reports/domain/entities/report_metrics.dart';
import 'package:proj/features/reports/presentation/providers/reports_providers.dart';
import 'package:proj/features/sales/data/farm_buyer.dart';
import 'package:proj/features/sales/data/farm_sale.dart';
import 'package:proj/features/sales/data/pig_listing.dart';
import 'package:proj/features/sales/presentation/pages/buyers_page.dart';
import 'package:proj/features/sales/presentation/pages/sales_page.dart';
import 'package:proj/features/sales/presentation/providers/farm_sales_provider.dart';
import 'package:proj/features/sales/presentation/providers/pig_marketplace_provider.dart';
import 'package:proj/features/settings/presentation/providers/farm_access_provider.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test('pig listing reads its posted image URL', () {
    final listing = PigListing.fromJson({
      'id': 'pig-1',
      'title': 'Healthy weaner',
      'breed': 'Large White',
      'quantity': 1,
      'price_per_pig': '18000.00',
      'currency': 'KES',
      'status': 'available',
      'image_url': 'https://api.example.test/storage/pig.jpg',
    });

    expect(listing.imageUrl, 'https://api.example.test/storage/pig.jpg');
  });

  testWidgets('sales page displays farm orders and report metrics', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const SalesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My sales'));
    await tester.pumpAndSettle();

    expect(find.text('Farm sales'), findsWidgets);
    expect(find.text('SALE-1001'), findsOneWidget);
    expect(find.text('Nakuru Pork Shop'), findsOneWidget);
    expect(find.text('Record sale'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('buyers page displays farm buyer contact records', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const BuyersPage()));
    await tester.pumpAndSettle();

    expect(find.text('Buyers'), findsOneWidget);
    expect(find.text('Nakuru Pork Shop'), findsOneWidget);
    expect(find.textContaining('+254700000001'), findsOneWidget);
    expect(find.text('Add buyer'), findsOneWidget);
  });
}

Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_TestAuthNotifier.new),
      farmSalesProvider.overrideWith(_TestFarmSalesNotifier.new),
      farmAccessProvider.overrideWith(_TestFarmAccessNotifier.new),
      pigMarketplaceProvider.overrideWith(_TestPigMarketplaceNotifier.new),
      reportsApiProvider.overrideWithValue(_FakeReportsApi(_metrics)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _TestPigMarketplaceNotifier extends PigMarketplaceNotifier {
  @override
  Future<List<PigListing>> build() async => const [];
}

final _farm = const Farm(id: 'farm-1', name: 'Alpha Farm');
final _session = Session(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: const User(
    id: 'owner-1',
    name: 'Farm Owner',
    email: 'owner@example.com',
    role: UserRole.farmOwner,
  ),
  farms: [_farm],
  selectedFarm: _farm,
);
final _metrics = ReportMetrics(
  totalRevenue: 125000,
  totalExpenses: 42000,
  mortalityRate: 4.2,
  averageGrowth: 18.5,
  feedConsumption: 960,
  salesCount: 11,
  vaccinationCompletion: 92.5,
  startDate: DateTime(2026, 9, 1),
  endDate: DateTime(2026, 9, 30),
);

class _TestAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<Session?> build() => AsyncData(_session);
}

class _TestFarmSalesNotifier extends FarmSalesNotifier {
  @override
  Future<FarmSalesState> build() async => FarmSalesState(
    buyers: [
      const FarmBuyer(
        id: 'buyer-1',
        name: 'Nakuru Pork Shop',
        phone: '+254700000001',
        company: 'Nakuru Pork Shop',
      ),
    ],
    sales: [
      FarmSale(
        id: 'sale-1',
        reference: 'SALE-1001',
        customerId: 'buyer-1',
        customerName: 'Nakuru Pork Shop',
        status: 'pending',
        totalAmount: 30000,
        currency: 'KES',
        orderedAt: DateTime(2026, 10, 6),
        items: const [
          FarmSaleItem(name: 'Grower pig', quantity: 2, unitPrice: 15000),
        ],
      ),
    ],
  );
}

class _TestFarmAccessNotifier extends FarmAccessNotifier {
  @override
  Future<FarmAccessState> build() async => const FarmAccessState(members: []);
}

class _FakeReportsApi extends ReportsApi {
  _FakeReportsApi(this.metrics) : super(Dio());
  final ReportMetrics metrics;

  @override
  Future<ReportMetrics> getMetrics(
    String farmId, {
    required String dateRange,
    DateTime? startDate,
    DateTime? endDate,
  }) async => metrics;
}
