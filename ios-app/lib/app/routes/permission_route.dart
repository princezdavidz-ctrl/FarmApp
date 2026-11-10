import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/settings/presentation/providers/farm_access_provider.dart';
import '../../security/authorization/permissions.dart';
import '../../security/authorization/roles.dart';
import 'app_routes.dart';

class PermissionRoute extends ConsumerWidget {
  const PermissionRoute({
    required this.permission,
    required this.child,
    super.key,
  });

  final AppPermission permission;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final role = session?.user.role;
    if (role == UserRole.farmOwner || role == UserRole.superAdmin) {
      return child;
    }
    if (session == null) return const SizedBox.shrink();

    return ref
        .watch(farmAccessProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Feature access')),
            body: _AccessMessage(
              message: 'Could not verify your access. Please try again.',
              onReturn: () {
                ref.invalidate(farmAccessProvider);
                context.go(AppRoutes.home);
              },
            ),
          ),
          data: (access) {
            if (access.permissionsFor(session.user.id).contains(permission)) {
              return child;
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Feature unavailable')),
              body: _AccessMessage(
                message:
                    'The farm owner has not granted access to this feature.',
                onReturn: () => context.go(AppRoutes.home),
              ),
            );
          },
        );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.message, required this.onReturn});

  final String message;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onReturn,
            child: const Text('Back to dashboard'),
          ),
        ],
      ),
    ),
  );
}
