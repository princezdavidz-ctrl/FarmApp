import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../security/authorization/roles.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_scaffold.dart';

class AccountTypePage extends ConsumerWidget {
  const AccountTypePage({super.key});

  static const accountTypes = [
    (
      UserRole.farmOwner,
      'Farm owner',
      'Own and oversee one or more farms.',
      Icons.business_outlined,
    ),
    (
      UserRole.farmManager,
      'Farm manager',
      'Coordinate daily operations and teams.',
      Icons.manage_accounts_outlined,
    ),
    (
      UserRole.farmWorker,
      'Farm worker',
      'Complete tasks and care for the herd.',
      Icons.agriculture_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoles = ref.watch(onboardingProvider).roles;
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
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const OnboardingHeader(
              title: 'Choose your account type',
              eyebrow: 'Step 3 of 4 · Account type',
              subtitle:
                  'Choose the role that best matches your work on the farm.',
            ),
            const SizedBox(height: 24),
            ...accountTypes.map((accountType) {
              final (role, title, description, icon) = accountType;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: selectedRoles.contains(role)
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                child: RadioListTile<UserRole>(
                  value: role,
                  // ignore: deprecated_member_use
                  groupValue: selectedRoles.isEmpty
                      ? null
                      : selectedRoles.first,
                  // ignore: deprecated_member_use
                  onChanged: (selected) => ref
                      .read(onboardingProvider.notifier)
                      .toggleRole(role, selected != null),
                  secondary: Icon(icon),
                  title: Text(title),
                  subtitle: Text(description),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              );
            }),
          ],
        ),
      ),
      actions: Row(
        children: [
          TextButton(
            onPressed: () => context.go(AppRoutes.country),
            child: const Text('Back'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: selectedRoles.isEmpty
                ? null
                : () => context.go(
                    selectedRoles.contains(UserRole.farmOwner)
                        ? AppRoutes.herdSetup
                        : AppRoutes.createAccount,
                  ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
