import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../security/authentication/biometric_auth.dart';
import '../../../../app/routes/app_routes.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/permission_card.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 76, 24, 24),
              children: [
            const OnboardingHeader(
              title: 'Stay in the loop',
              subtitle:
                  'Choose the permissions Farm App needs to support your daily farm work.',
            ),
            const SizedBox(height: 28),
            PermissionCard(
              title: 'Notifications',
              icon: Icons.notifications_none,
              enabled: state.notifications,
              onChanged: (value) => ref
                  .read(onboardingProvider.notifier)
                  .setPermissions(
                    notifications: value,
                    location: state.location,
                  ),
              description:
                  'Pregnancy reminders, vaccination alerts, task reminders, and low feed notifications.',
            ),
            const SizedBox(height: 12),
            PermissionCard(
              title: 'Location',
              icon: Icons.location_on_outlined,
              enabled: state.location,
              onChanged: (value) => ref
                  .read(onboardingProvider.notifier)
                  .setPermissions(
                    notifications: state.notifications,
                    location: value,
                  ),
              description:
                  'Farm location, weather integration, multi-farm verification, and report metadata.',
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Biometric unlock'),
              subtitle: const Text(
                'Use Face ID, Touch ID, or your device biometrics when available.',
              ),
              trailing: Switch(
                value: state.biometric,
                onChanged: (value) async {
                  if (!value) {
                    ref.read(onboardingProvider.notifier).setBiometric(false);
                    return;
                  }
                  try {
                    final biometricAuth = BiometricAuth();
                    if (await biometricAuth.isAvailable() &&
                        await biometricAuth.authenticate() &&
                        context.mounted) {
                      ref.read(onboardingProvider.notifier).setBiometric(true);
                    }
                  } on Exception catch (error) {
                    debugPrint('Biometric unlock unavailable: $error');
                  }
                },
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                ref
                    .read(onboardingProvider.notifier)
                    .setPermissions(notifications: true, location: true);
                context.go(AppRoutes.language);
              },
              child: const Text('Allow all'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go(AppRoutes.language),
              child: const Text('Continue'),
            ),
              ],
            ),
            Positioned(
              top: 0,
              right: 16,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.language),
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
