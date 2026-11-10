import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/subscription/presentation/pages/payment_status_page.dart';

void main() {
  testWidgets('shows M-Pesa waiting and confirmation guidance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentStatusPage(
          amount: 500,
          currency: 'KES',
          merchantRequestId: 'merchant-1',
          checkoutRequestId: 'checkout-1',
        ),
      ),
    );

    expect(find.text('M-Pesa payment requested'), findsOneWidget);
    expect(find.text('Awaiting confirmation'), findsOneWidget);
    expect(
      find.text(
        'Check your phone for the M-Pesa prompt and enter your PIN to complete the transaction.',
      ),
      findsOneWidget,
    );
  });
}
