import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proj/app/routes/app_routes.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/auth/data/datasource/auth_local_datasource_impl.dart';
import 'package:proj/features/settings/data/settings_api.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/security/authentication/pin_auth.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) =>
                    value != password.text ? 'Passwords do not match.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, (current.text, password.text));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    current.dispose();
    password.dispose();
    confirmation.dispose();
    if (values == null || !context.mounted) return;
    try {
      await SettingsApi(
        ref.read(dioProvider),
      ).changePassword(currentPassword: values.$1, newPassword: values.$2);
      if (context.mounted) _showMessage(context, 'Password updated.');
    } catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          'Could not change password: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _setPin(BuildContext context) async {
    final pin = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set 4-digit PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN'),
                validator: (value) =>
                    value == null || !RegExp(r'^\d{4}$').hasMatch(value)
                    ? 'Enter exactly four digits.'
                    : null,
              ),
              TextFormField(
                controller: confirmation,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                validator: (value) =>
                    value != pin.text ? 'PINs do not match.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, pin.text);
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
    pin.dispose();
    confirmation.dispose();
    if (value == null || !context.mounted) return;
    try {
      await PinAuth().setPin(value);
      if (context.mounted) _showMessage(context, 'PIN saved securely.');
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Could not save PIN: $error', isError: true);
      }
    }
  }

  Future<void> _logoutAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of all devices?'),
        content: const Text(
          'This will revoke every Farm App session, including this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await SettingsApi(ref.read(dioProvider)).logoutAllSessions();
      await AuthLocalDataSourceImpl().clear();
      await ref.read(authServiceProvider).clearSession();
      await PinAuth().clear();
      ref.read(authProvider.notifier).clearSession();
      if (context.mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          'Could not sign out all devices: $error',
          isError: true,
        );
      }
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securitySettings = ref.watch(securitySettingsProvider);

    return securitySettings.when(
      data: (settings) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          // Password & PIN Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password & PIN',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _SecurityTile(
                    icon: Icons.lock,
                    title: 'Change Password',
                    onTap: () => _changePassword(context, ref),
                  ),
                  const Divider(),
                  _SecurityTile(
                    icon: Icons.numbers,
                    title: 'Set 4-Digit PIN',
                    onTap: () => _setPin(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Biometric Security
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biometric Login',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  SwitchListTile(
                    title: const Text('Fingerprint Login'),
                    subtitle: const Text('Use fingerprint to unlock the app'),
                    value: settings.hasBiometricEnabled,
                    onChanged: (value) async {
                      try {
                        await ref
                            .read(securitySettingsProvider.notifier)
                            .updateBiometric(value);
                      } catch (error) {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Could not update fingerprint login: $error',
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Two-Factor Authentication
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email verification codes are required for account sign-in.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Session Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  if (settings.lastPasswordChange != null)
                    Text(
                      'Last password changed: ${settings.lastPasswordChange}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  FilledButton(
                    onPressed: () => _logoutAll(context, ref),
                    child: const Text('Sign Out From All Devices'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading security settings: $err')),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
