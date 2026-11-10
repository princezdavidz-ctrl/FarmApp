import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/settings/data/settings_local_data_source.dart';
import 'package:proj/features/settings/domain/entities/user_preferences.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/l10n/generated/app_localizations.dart';

void main() {
  test('locale follows persisted language changes and restores on new scope', () async {
    final storage = _MemorySettingsDataSource(
      UserPreferences.defaults().copyWith(language: 'sw'),
    );
    final container = ProviderContainer(
      overrides: [settingsLocalDataSourceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container.read(userPreferencesProvider.future);
    expect(container.read(appLanguageProvider), 'sw');

    await container.read(userPreferencesProvider.notifier).updateLanguage('en');
    expect(storage.preferences.language, 'en');
    expect(container.read(appLanguageProvider), 'en');

    final restartedContainer = ProviderContainer(
      overrides: [settingsLocalDataSourceProvider.overrideWithValue(storage)],
    );
    addTearDown(restartedContainer.dispose);
    await restartedContainer.read(userPreferencesProvider.future);
    expect(restartedContainer.read(appLanguageProvider), 'en');
  });

  test('unsupported stored locale safely falls back to English', () async {
    final container = ProviderContainer(
      overrides: [
        settingsLocalDataSourceProvider.overrideWithValue(
          _MemorySettingsDataSource(
            UserPreferences.defaults().copyWith(language: 'fr'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userPreferencesProvider.future);
    expect(container.read(appLanguageProvider), 'en');
  });

  testWidgets('changing saved locale immediately translates visible UI', (
    tester,
  ) async {
    final storage = _MemorySettingsDataSource(UserPreferences.defaults());
    final container = ProviderContainer(
      overrides: [settingsLocalDataSourceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: Locale(ref.watch(appLanguageProvider)),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Text(AppLocalizations.of(context).settings),
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(userPreferencesProvider.future);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await container.read(userPreferencesProvider.notifier).updateLanguage('sw');
    await tester.pumpAndSettle();
    expect(find.text('Mipangilio'), findsOneWidget);
  });
}

class _MemorySettingsDataSource extends SettingsLocalDataSource {
  _MemorySettingsDataSource(this.preferences);

  UserPreferences preferences;

  @override
  Future<UserPreferences> readPreferences() async => preferences;

  @override
  Future<void> savePreferences(UserPreferences updated) async {
    preferences = updated;
  }
}
