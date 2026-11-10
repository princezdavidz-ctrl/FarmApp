import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proj/app/routes/app_routes.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/data/datasource/auth_local_datasource_impl.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/security/authentication/pin_auth.dart';
import 'package:proj/security/authentication/biometric_auth.dart';
import 'package:proj/features/settings/data/settings_local_data_source.dart';

class PinLockPage extends ConsumerStatefulWidget {
  const PinLockPage({super.key});

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends ConsumerState<PinLockPage> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;
  bool _loading = true;
  bool _hasPin = false;
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUnlockOptions();
  }

  Future<void> _loadUnlockOptions() async {
    try {
      final hasPin = await PinAuth().hasPin;
      final security = await SettingsLocalDataSource().readSecuritySettings();
      if (!mounted) return;
      setState(() {
        _hasPin = hasPin;
        _fingerprintEnabled = security.hasBiometricEnabled;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not load unlock settings: $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _unlock() async {
    if (_checking) return;
    if (!RegExp(r'^\d{4}$').hasMatch(_pinController.text)) {
      setState(() => _error = 'Enter your four-digit PIN.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final verified = await PinAuth().verify(_pinController.text);
      if (!mounted) return;
      if (!verified) {
        setState(() => _error = 'Incorrect PIN. Try again or sign in.');
        return;
      }
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        if (mounted) context.go(AppRoutes.login);
        return;
      }
      if (mounted) {
        context.go(
          session.selectedFarm == null
              ? AppRoutes.farmSelection
              : AppRoutes.home,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not verify PIN: $error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _usePasswordSignIn() async {
    try {
      await AuthLocalDataSourceImpl().clear();
      await ref.read(authServiceProvider).clearSession();
      await PinAuth().clear();
      ref.read(authProvider.notifier).clearSession();
      if (mounted) context.go(AppRoutes.login);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not return to sign in: $error');
      }
    }
  }

  Future<void> _unlockWithFingerprint() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final authenticated = await BiometricAuth().authenticate();
      if (!authenticated) {
        if (mounted) setState(() => _error = 'Fingerprint was not verified.');
        return;
      }
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        if (mounted) context.go(AppRoutes.login);
        return;
      }
      if (mounted) {
        context.go(
          session.selectedFarm == null
              ? AppRoutes.farmSelection
              : AppRoutes.home,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Fingerprint sign-in failed: $error');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 56),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    Text(
                      'Enter your PIN',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (_hasPin)
                      TextField(
                        controller: _pinController,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: '4-digit PIN',
                          errorText: _error,
                        ),
                        onSubmitted: (_) => _unlock(),
                      )
                    else if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_fingerprintEnabled) ...[
                      const SizedBox(height: AppDimensions.spacingMedium),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _checking ? null : _unlockWithFingerprint,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Unlock with fingerprint'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (_hasPin)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _checking ? null : _unlock,
                          child: _checking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Unlock with PIN'),
                        ),
                      ),
                    TextButton(
                      onPressed: _checking ? null : _usePasswordSignIn,
                      child: const Text('Sign in with password instead'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
