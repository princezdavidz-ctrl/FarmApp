import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../security/authorization/roles.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../../shared/widgets/profile_avatar.dart';
import '../providers/farm_access_provider.dart';
import '../providers/profile_image_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final user = session?.user;
    final farm = session?.selectedFarm ?? session?.farms.firstOrNull;
    final isFarmOwner = user?.role == UserRole.farmOwner;
    final farmAccess = isFarmOwner ? ref.watch(farmAccessProvider) : null;
    final initials = (user?.name.isNotEmpty ?? false)
        ? user!.name.trim()[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.pagePadding,
          AppDimensions.pagePadding,
          AppDimensions.pagePadding,
          32,
        ),
        children: [
          Card(
            color: AppColors.deepGreen,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(initials: initials),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: IconButton.filled(
                          tooltip: 'Change profile photo',
                          icon: const Icon(Icons.photo_camera_outlined),
                          iconSize: 17,
                          onPressed: () => _chooseProfileImage(context, ref),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Your profile',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.inverseText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'Sign in to view your account',
                          style: TextStyle(color: AppColors.inverseMutedText),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inverseText.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _roleLabel(user?.role.name),
                            style: TextStyle(color: AppColors.inverseText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Text('Account details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                _ProfileDetailTile(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: user?.name ?? 'Not available',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileDetailTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? 'Not available',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Text('Farm workspace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.agriculture_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Farms'),
                  subtitle: Text(
                    farm?.name ?? 'Complete setup to connect a farm',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${session?.farms.length ?? 0}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.deepGreen,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.go(AppRoutes.farmSelection),
                ),
                if (isFarmOwner) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: const Text('Subscription'),
                    subtitle: Text(
                      farm?.subscriptionPlan ?? 'No active subscription',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.billing),
                  ),
                  const Divider(height: 1, indent: 56),
                  farmAccess!.when(
                    loading: () => const ListTile(
                      leading: Icon(
                        Icons.groups_outlined,
                        color: AppColors.primaryGreen,
                      ),
                      title: Text('Farm members'),
                      trailing: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (error, _) => ListTile(
                      leading: const Icon(
                        Icons.groups_outlined,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text('Farm members'),
                      subtitle: Text('Could not load member count: $error'),
                      trailing: const Icon(Icons.error_outline),
                    ),
                    data: (state) => ListTile(
                      leading: const Icon(
                        Icons.groups_outlined,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text('Farm members'),
                      subtitle: Text(
                        '${state.members.length} member${state.members.length == 1 ? '' : 's'} have access',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AppRoutes.farmManagement),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseProfileImage(BuildContext context, WidgetRef ref) async {
    try {
      final selected = await ref
          .read(profileImageProvider.notifier)
          .chooseFromGallery();
      if (context.mounted && !selected) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update profile photo.')),
        );
      }
    }
  }

  String _roleLabel(String? role) => switch (role) {
    'farmOwner' => 'Farm owner',
    'farmManager' => 'Farm manager',
    'farmWorker' => 'Farm worker',
    _ => 'Farm member',
  };
}

class _ProfileDetailTile extends StatelessWidget {
  const _ProfileDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}
