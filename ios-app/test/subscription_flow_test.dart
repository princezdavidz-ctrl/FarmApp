import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/onboarding/presentation/pages/payment_method_page.dart';
import 'package:proj/security/authorization/roles.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._session);

  final Session _session;

  @override
  AsyncValue<Session?> build() => AsyncData(_session);
}

void main() {
  testWidgets('shows payment method options for the recommended plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PaymentMethodPage(
            selectedPlan: {
              'name': 'Growth',
              'amount': 2500,
              'currency': 'KES',
              'description': 'For growing teams and herds.',
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('How would you like to pay?'), findsOneWidget);
    expect(find.text('M-Pesa'), findsOneWidget);
    expect(find.text('Airtel Money'), findsOneWidget);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('Proceed'), findsOneWidget);
  });

  testWidgets('calls the M-Pesa subscription endpoint before continuing', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    var called = false;
    var lastPath = '';
    var lastData = <String, dynamic>{};

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          called = true;
          lastPath = options.path;
          if (options.data is Map<String, dynamic>) {
            lastData = Map<String, dynamic>.from(options.data as Map);
          } else if (options.data is Map) {
            lastData = Map<String, dynamic>.from(options.data as Map);
          }
          handler.resolve(
            Response(
              data: {
                'payment': {
                  'status': 'pending',
                  'merchant_request_id': 'MR123',
                  'checkout_request_id': 'QC123',
                  'result_description':
                      'M-Pesa prompt sent. Check your phone and enter your PIN.',
                },
              },
              statusCode: 201,
              requestOptions: options,
            ),
          );
        },
      ),
    );

    final session = Session(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: const User(
        id: 'user-1',
        name: 'Test User',
        email: 'user@example.com',
        phone: '0746933820',
        role: UserRole.farmOwner,
      ),
      farms: const [Farm(id: 'farm-1', name: 'Demo Farm', motherPigCount: 12)],
      selectedFarm: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authProvider.overrideWith(() => _TestAuthNotifier(session)),
        ],
        child: MaterialApp(
          home: const PaymentMethodPage(
            selectedPlan: {
              'code': 'starter',
              'name': 'Starter',
              'amount': 500,
              'currency': 'KES',
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Proceed'));
    await tester.tap(find.text('Proceed'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(lastPath, '/farms/farm-1/subscription/payment');
    expect(lastData, {'plan': 'starter', 'phone': '254746933820'});
  });
}
