import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/l10n/generated/app_localizations.dart';

class AppPreferencesSection extends ConsumerWidget {
  const AppPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref.watch(userPreferencesProvider);

    return preferences.when(
      data: (prefs) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.languageLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _buildDropdown(
                    context,
                    l10n.selectLanguage,
                    prefs.language,
                    [('en', 'English'), ('sw', 'Kiswahili')],
                    (value) {
                      ref
                          .read(userPreferencesProvider.notifier)
                          .updateLanguage(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.darkMode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Switch(
                        value: prefs.isDarkMode,
                        onChanged: (value) {
                          ref
                              .read(userPreferencesProvider.notifier)
                              .updateTheme(value);
                        },
                      ),
                    ],
                  ),
                  Text(
                    l10n.darkModeDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.measurementUnits,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _buildDropdown(
                    context,
                    l10n.weightUnit,
                    prefs.weightUnit,
                    [('kg', 'Kilograms (kg)'), ('lb', 'Pounds (lb)')],
                    (value) {
                      ref
                          .read(userPreferencesProvider.notifier)
                          .updateWeightUnit(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dateFormat,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _buildDropdown(
                    context,
                    l10n.selectFormat,
                    prefs.dateFormat,
                    [
                      ('dd/MM/yyyy', 'DD/MM/YYYY'),
                      ('MM/dd/yyyy', 'MM/DD/YYYY'),
                      ('yyyy-MM-dd', 'YYYY-MM-DD'),
                    ],
                    (value) {
                      ref
                          .read(userPreferencesProvider.notifier)
                          .updateDateFormat(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.currency,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _buildDropdown(
                    context,
                    l10n.selectCurrency,
                    prefs.currency,
                    [
                      ('KES', 'Kenyan Shilling (KES)'),
                      ('USD', 'US Dollar (USD)'),
                    ],
                    (value) {
                      ref
                          .read(userPreferencesProvider.notifier)
                          .updateCurrency(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    String label,
    String currentValue,
    List<(String, String)> options,
    Function(String) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.tune),
      ),
      items: options
          .map(
            (option) =>
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
