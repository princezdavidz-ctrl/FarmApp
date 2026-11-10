import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/presentation/pages/login_page.dart';
import 'package:proj/features/auth/presentation/pages/otp_verification_page.dart';

void main() {
  testWidgets(
    'login page stays password-first and does not offer OTP sign-in',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      expect(find.text('Use OTP'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  testWidgets('login requires agreement before enabling sign-in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    final agreement = find.byKey(const ValueKey('login-agreement-checkbox'));
    expect(tester.widget<FilledButton>(signIn).onPressed, isNull);
    expect(find.text('User Agreement'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.ensureVisible(agreement);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: agreement, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(agreement).value, isTrue);
    expect(tester.widget<FilledButton>(signIn).onPressed, isNotNull);
  });

  testWidgets(
    'otp verification page asks for the code sent to the registered email',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationPage(
              challengeId: 'challenge-test',
              destination: 'u***@example.test',
              rememberMe: false,
            ),
          ),
        ),
      );

      expect(find.text('OTP verification'), findsOneWidget);
      expect(find.textContaining('u***@example.test'), findsOneWidget);
      expect(find.text('Verify and sign in'), findsOneWidget);
    },
  );

  testWidgets('OTP remains on screen when returning from the mail app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OtpVerificationPage(
            challengeId: 'challenge-test',
            destination: 'u***@example.test',
            rememberMe: false,
          ),
        ),
      ),
    );

    final codeField = find.byKey(const ValueKey('login-otp-code'));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).autofillHints,
      const [AutofillHints.oneTimeCode],
    );
    await tester.enterText(codeField, '12ab3456');
    await tester.pump();
    expect(find.text('123456'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('OTP verification'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-otp-code')), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });
}
