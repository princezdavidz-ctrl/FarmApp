import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../domain/entities/session.dart';
import '../providers/auth_provider.dart';
import '../../../../security/authentication/pin_auth.dart';
import '../../../settings/data/settings_local_data_source.dart';
import '../providers/auth_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  final DateTime _startedAt = DateTime.now();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    Session? session;
    try {
      session = await ref.read(sessionRestoreProvider.future);
    } catch (_) {
      ref.read(authProvider.notifier).clearSession();
    }
    if (!mounted) return;
    if (session != null) {
      bool hasPin;
      try {
        final security = await SettingsLocalDataSource().readSecuritySettings();
        hasPin = await PinAuth().hasPin || security.hasBiometricEnabled;
      } catch (_) {
        await _finishSplashTransition();
        if (!mounted) return;
        _navigated = true;
        context.go(AppRoutes.login);
        return;
      }
      if (!mounted) return;
      await _finishSplashTransition();
      if (!mounted) return;
      _navigated = true;
      context.go(
        hasPin
            ? AppRoutes.pinLock
            : session.selectedFarm != null
            ? AppRoutes.home
            : AppRoutes.farmSelection,
      );
      return;
    }

    bool onboardingCompleted;
    try {
      onboardingCompleted = await ref.read(onboardingCompletedProvider.future);
    } catch (_) {
      onboardingCompleted = true;
    }
    if (!mounted) return;
    await _finishSplashTransition();
    if (!mounted) return;
    _navigated = true;
    context.go(onboardingCompleted ? AppRoutes.login : AppRoutes.language);
  }

  Future<void> _finishSplashTransition() async {
    const minimumVisible = Duration(milliseconds: 560);
    final remaining = minimumVisible - DateTime.now().difference(_startedAt);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: reduceMotion ? const AlwaysStoppedAnimation(1) : _fade,
          child: ScaleTransition(
            scale: reduceMotion ? const AlwaysStoppedAnimation(1) : _scale,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.agriculture,
                    size: 144,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'Farm App',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Farm App',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Farm management',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 104,
                    child: LinearProgressIndicator(
                      value: reduceMotion ? 0.45 : null,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Preparing your farm…',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
