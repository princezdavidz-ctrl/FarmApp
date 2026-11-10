import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/session.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../security/authorization/roles.dart';

abstract final class RouteGuard {
  static const publicRoutes = {
    '/splash',
    '/pin-lock',
    '/login',
    '/forgot-password',
    '/otp-verification',
    '/session-expired',
    '/permissions',
    '/language',
    '/country',
    '/account-type',
    '/create-account',
    '/herd-setup',
    '/subscription',
    '/payment-method',
    '/farm-selection',
  };

  static bool isPublic(String location) => publicRoutes.contains(location);

  static String? redirectFor(
    Session? session,
    String location, {
    UserRole? role,
  }) {
    final resolvedRole = role ?? session?.user.role;

    if (location == '/subscription' && resolvedRole != UserRole.farmOwner) {
      return '/';
    }

    if (isPublic(location)) return null;
    if (session == null) return '/splash';
    if (session.selectedFarm == null && location == '/farm-management') {
      return null;
    }
    if (session.selectedFarm == null) return '/farm-selection';
    return null;
  }

  /// Splash owns the asynchronous session check before entering the shell.
  static String? redirect(BuildContext context, GoRouterState state) {
    final session = ProviderScope.containerOf(
      context,
    ).read(authProvider).valueOrNull;
    return redirectFor(session, state.uri.path, role: session?.user.role);
  }
}
