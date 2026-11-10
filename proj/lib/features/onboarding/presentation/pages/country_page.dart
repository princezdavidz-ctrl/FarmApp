import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/country_radio_tile.dart';
import '../widgets/onboarding_header.dart';
import '../../data/country_catalog.dart';
import '../../data/location_country_service.dart';
import '../widgets/onboarding_scaffold.dart';

class CountryPage extends ConsumerStatefulWidget {
  const CountryPage({super.key});

  static const countries = [
    'Kenya',
    'Uganda',
    'Tanzania',
    'Rwanda',
    'Burundi',
    'Ethiopia',
    'South Sudan',
  ];

  @override
  ConsumerState<CountryPage> createState() => _CountryPageState();
}

class _CountryPageState extends ConsumerState<CountryPage> {
  String query = '';
  bool _detecting = true;

  @override
  void initState() {
    super.initState();
    _detectCountry();
  }

  Future<void> _detectCountry() async {
    try {
      final detected = await LocationCountryService().detectCountry();
      if (!mounted || detected == null) return;
      final match = countryCatalog
          .where(
            (country) => country.name.toLowerCase() == detected.toLowerCase(),
          )
          .firstOrNull;
      if (match != null && ref.read(onboardingProvider).country == null) {
        ref.read(onboardingProvider.notifier).setCountry(match.name);
      }
    } on Exception {
      // Location is a convenience; manual country selection remains available.
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(onboardingProvider).country;
    final countries = countryCatalog
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (query.isEmpty) {
      countries.sort((first, second) {
        if (first.name == 'Kenya') {
          return -1;
        }
        if (second.name == 'Kenya') {
          return 1;
        }
        return first.name.compareTo(second.name);
      });
    }
    return OnboardingScaffold(
      topAction: TextButton(
        onPressed: () async {
          await ref.read(onboardingStorageProvider).markCompleted();
          if (context.mounted) context.go(AppRoutes.createAccount);
        },
        child: const Text('Skip'),
      ),
      body: OnboardingEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            const OnboardingHeader(
              eyebrow: 'Step 2 of 4 · Farm location',
              title: 'Where is your farm?',
              subtitle:
                  'We use this to tailor currency, dates, weather, and regional reports.',
            ),
            const SizedBox(height: 24),
            if (_detecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Checking your location…'),
                  ],
                ),
              ),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search countries',
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: countries
                  .map(
                    (country) => CountryRadioTile(
                      country: '${country.flag}  ${country.name}',
                      selected: selected == country.name,
                      onChanged: (value) => ref
                          .read(onboardingProvider.notifier)
                          .setCountry(value),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      actions: Row(
        children: [
          TextButton(
            onPressed: () => context.go(AppRoutes.language),
            child: const Text('Back'),
          ),
          const Spacer(),
          Flexible(
            child: FilledButton(
              onPressed: selected == null
                  ? null
                  : () => context.go(AppRoutes.accountType),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
