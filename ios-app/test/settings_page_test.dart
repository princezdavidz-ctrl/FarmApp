import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/settings/presentation/pages/settings_page.dart';
import 'package:proj/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('settings page shows farm, billing and security sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);

    expect(find.text('Account settings'), findsOneWidget);
    expect(find.text('Farm configuration'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Billing & subscription'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Billing & subscription'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Security & sessions'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Security & sessions'), findsOneWidget);
  });
}
