import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/settings/domain/entities/user_preferences.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/l10n/generated/app_localizations.dart';

class NotificationSection extends ConsumerWidget {
  const NotificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final l10n = AppLocalizations.of(context);
    final notificationLabel = l10n?.notificationSound ?? 'Notification sound';

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
                    'Notification Preferences',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  DropdownButtonFormField<String>(
                    initialValue:
                        {
                          'default',
                          'chime',
                          'alert',
                          'silent',
                        }.contains(prefs.notificationSound)
                        ? prefs.notificationSound
                        : 'default',
                    decoration: InputDecoration(
                      labelText: notificationLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'default',
                        child: Text(l10n?.phoneDefault ?? 'Phone default'),
                      ),
                      DropdownMenuItem(
                        value: 'chime',
                        child: Text(l10n?.chime ?? 'Chime'),
                      ),
                      DropdownMenuItem(
                        value: 'alert',
                        child: Text(l10n?.alert ?? 'Alert'),
                      ),
                      DropdownMenuItem(
                        value: 'silent',
                        child: Text(l10n?.silent ?? 'Silent'),
                      ),
                    ],
                    onChanged: (sound) {
                      if (sound != null) _updateSound(context, ref, sound);
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  ..._buildNotificationTiles(context, ref, prefs),
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
                    'Notification Channels',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    value: prefs.notificationChannels['push'] ?? true,
                    onChanged: (enabled) =>
                        _updateChannel(context, ref, 'push', enabled),
                  ),
                  SwitchListTile(
                    title: const Text('SMS Notifications'),
                    value: prefs.notificationChannels['sms'] ?? false,
                    onChanged: (enabled) =>
                        _updateChannel(context, ref, 'sms', enabled),
                  ),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    value: prefs.notificationChannels['email'] ?? true,
                    onChanged: (enabled) =>
                        _updateChannel(context, ref, 'email', enabled),
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

  Future<void> _updateSound(
    BuildContext context,
    WidgetRef ref,
    String sound,
  ) async {
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .updateNotificationSound(sound);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The setting was saved, but feeding reminders could not be updated.',
          ),
        ),
      );
    }
  }

  Future<void> _updateChannel(
    BuildContext context,
    WidgetRef ref,
    String channel,
    bool enabled,
  ) async {
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .updateNotificationChannel(channel, enabled);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save notification setting.')),
      );
    }
  }

  List<Widget> _buildNotificationTiles(
    BuildContext context,
    WidgetRef ref,
    UserPreferences prefs,
  ) {
    final notifications = [
      (
        'vaccinations',
        'Vaccination Reminders',
        'Get alerts for vaccination schedules',
      ),
      (
        'feeding',
        'Feeding Reminders',
        'Reminders for feeding times and amounts',
      ),
      ('breeding', 'Insemination Alerts', 'Alerts for insemination events'),
      (
        'lowStock',
        'Low Stock Alerts',
        'Notifications when feed or supplies are low',
      ),
      ('sales', 'Sales Notifications', 'Updates on sales and orders'),
      ('payments', 'Payment Notifications', 'Alerts for payments and invoices'),
    ];

    return notifications.map((tuple) {
      final (type, title, subtitle) = tuple;
      return Column(
        children: [
          SwitchListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            value: prefs.notifications[type] ?? true,
            onChanged: (value) {
              ref
                  .read(userPreferencesProvider.notifier)
                  .updateNotificationToggle(type, value);
            },
          ),
          if (type != 'payments') const Divider(),
        ],
      );
    }).toList();
  }
}
