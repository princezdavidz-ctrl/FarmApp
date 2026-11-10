import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/l10n/generated/app_localizations.dart';

import '../../../../app/routes/app_routes.dart';
import '../../data/language_catalog.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/language_card.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_scaffold.dart';

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  String query = '';

  Future<void> _selectLanguage(AppLanguage language) async {
    ref
        .read(onboardingProvider.notifier)
        .setLanguage(name: language.name, code: language.code);

    // Only English and Kiswahili have bundled translations. Persist the
    // supported choice so the preferences load cannot reset it to English.
    if (language.code != 'en' && language.code != 'sw') return;
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .updateLanguage(language.code);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.languageChangeFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(onboardingProvider).language;
    final languages = languageCatalog
        .where((item) => item.code == 'en' || item.code == 'sw')
        .where(
          (item) => '${item.name} ${item.nativeName}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return OnboardingScaffold(
      topAction: TextButton(
        onPressed: () async {
          await ref.read(onboardingStorageProvider).markCompleted();
          if (context.mounted) context.go(AppRoutes.createAccount);
        },
        child: Text(l10n.skip),
      ),
      body: OnboardingEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            OnboardingHeader(
              eyebrow: l10n.stepLanguage,
              title: l10n.chooseLanguage,
              subtitle: l10n.languageIntro,
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: l10n.searchLanguages,
              ),
            ),
            const SizedBox(height: 16),
            ...languages.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LanguageCard(
                  flag: item.code.toUpperCase(),
                  nativeName: item.nativeName,
                  translation: item.name,
                  selected: selected == item.name,
                  onTap: () => _selectLanguage(item),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: Row(
        children: [
          TextButton(
            onPressed: () => context.go(AppRoutes.permissions),
            child: Text(l10n.back),
          ),
          const Spacer(),
          Flexible(
            child: FilledButton(
              onPressed: () {
                final isMobile =
                    !kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS);
                if (isMobile) unawaited(_requestRuntimePermissions());
                context.go(AppRoutes.country);
              },
              child: Text(l10n.continueButton),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestRuntimePermissions() async {
    try {
      await [Permission.notification, Permission.location].request();
    } on Exception {
      // A denied or unavailable permission must not block onboarding.
    }
  }
}
