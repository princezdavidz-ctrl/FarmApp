import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/generated/app_localizations.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import '../shared/providers/theme_provider.dart';
import '../shared/providers/connectivity_provider.dart';
import '../features/settings/presentation/providers/settings_providers.dart';
import '../features/notifications/data/notifications_api.dart';
import '../features/notifications/presentation/providers/notifications_provider.dart';
import '../features/notifications/data/push_notification_service.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _AppRoot());
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  late final PushNotificationService _pushNotifications;
  late final ProviderSubscription _authSubscription;

  @override
  void initState() {
    super.initState();
    _pushNotifications = PushNotificationService(ref.read(dioProvider));
    _authSubscription = ref.listenManual(authProvider, (previous, next) {
      if (next.valueOrNull != null) {
        unawaited(
          _pushNotifications.registerDevice().catchError((error) {
            debugPrint('Push notification setup failed: $error');
          }),
        );
      } else if (previous?.valueOrNull != null) {
        unawaited(
          _pushNotifications.unregisterDevice().catchError((error) {
            debugPrint('Push-token removal failed: $error');
          }),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      locale: Locale(ref.watch(appLanguageProvider)),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: AppRouter.router,
      builder: (context, child) =>
          _AppShell(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline =
        ref.watch(connectivityProvider).valueOrNull ==
        ConnectivityStatus.offline;
    final notification = ref
        .watch(notificationsProvider)
        .valueOrNull
        ?.firstWhereOrNull((item) => !item.isRead);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        if (isOffline)
          Material(
            color: Theme.of(context).colorScheme.error,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    l10n.noInternetConnection,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        _NotificationBanner(notification: notification),
        Expanded(child: child),
      ],
    );
  }
}

class _NotificationBanner extends ConsumerStatefulWidget {
  const _NotificationBanner({required this.notification});

  final FarmNotification? notification;

  @override
  ConsumerState<_NotificationBanner> createState() =>
      _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<_NotificationBanner> {
  static const _autoDismissDuration = Duration(seconds: 6);

  Timer? _autoDismissTimer;
  String? _dismissedNotificationId;

  @override
  void initState() {
    super.initState();
    _startAutoDismiss(widget.notification);
  }

  @override
  void didUpdateWidget(covariant _NotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notification?.id == widget.notification?.id) return;

    _autoDismissTimer?.cancel();
    _startAutoDismiss(widget.notification);
  }

  void _startAutoDismiss(FarmNotification? notification) {
    if (notification == null || notification.id == _dismissedNotificationId) {
      return;
    }
    _autoDismissTimer = Timer(_autoDismissDuration, () {
      if (!mounted || widget.notification?.id != notification.id) return;
      setState(() => _dismissedNotificationId = notification.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;

    if (notification == null || notification.id == _dismissedNotificationId) {
      return const SizedBox.shrink();
    }

    final color = switch (notification.severity) {
      'danger' => Colors.red,
      'warning' => Colors.orange,
      'success' => Colors.green,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => _openNotification(notification),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  ).dismissNotificationBanner,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    setState(() => _dismissedNotificationId = widget.notification?.id);
  }

  Future<void> _openNotification(FarmNotification notification) async {
    try {
      await ref
          .read(notificationsProvider.notifier)
          .markAsRead(notification.id);
    } finally {
      if (mounted) context.push(AppRoutes.notifications);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }
}

extension on Iterable<FarmNotification> {
  FarmNotification? firstWhereOrNull(bool Function(FarmNotification) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _counter++),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
