import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_providers.dart';
import '../services/google_sign_in_service.dart';
import '../services/apple_sign_in_service.dart';
import '../widgets/login_form.dart';
import '../widgets/server_settings_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _agreementAccepted = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6F1E9),
              AppColors.background,
              AppColors.background,
            ],
            stops: [0, 0.42, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.pagePadding,
                12,
                AppDimensions.pagePadding,
                AppDimensions.spacingLarge,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Server address',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface.withValues(
                            alpha: 0.8,
                          ),
                          foregroundColor: AppColors.deepGreen,
                        ),
                        icon: const Icon(Icons.settings_ethernet),
                        onPressed: () => showServerSettingsDialog(context, ref),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Container(
                        width: 124,
                        height: 124,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface.withValues(alpha: 0.8),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepGreen.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.agriculture,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to manage your farm with Farm App.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.outline.withValues(alpha: 0.45),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepGreen.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in to your account',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your details to continue.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          LoginForm(
                            canSubmit: _agreementAccepted,
                            onSubmit: (identifier, password, rememberMe) async {
                              if (!_agreementAccepted) return;
                              if (identifier.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter your email and password.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                final challenge = await ref.read(
                                  loginUseCaseProvider,
                                )(identifier, password, rememberMe: rememberMe);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'A sign-in code was sent to your email.',
                                      ),
                                    ),
                                  );
                                  context.go(
                                    '${AppRoutes.otpVerification}?challengeId=${Uri.encodeComponent(challenge.id)}&destination=${Uri.encodeComponent(challenge.destination)}&rememberMe=$rememberMe',
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unable to sign in. Please check your credentials and try again.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: AppDimensions.spacingSmall),
                          Material(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: CheckboxListTile(
                                key: const ValueKey('login-agreement-checkbox'),
                                value: _agreementAccepted,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                                onChanged: (accepted) => setState(
                                  () => _agreementAccepted = accepted ?? false,
                                ),
                                title: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('I agree to the '),
                                    InkWell(
                                      onTap: () => _showAgreement(
                                        context,
                                        'User Agreement',
                                      ),
                                      child: const Text(
                                        'User Agreement',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(' and '),
                                    InkWell(
                                      onTap: () => _showAgreement(
                                        context,
                                        'Privacy Policy',
                                      ),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text('.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          OutlinedButton.icon(
                            onPressed: !_agreementAccepted
                                ? null
                                : defaultTargetPlatform == TargetPlatform.iOS
                                ? _signInWithApple
                                : () async {
                                    try {
                                      final idToken =
                                          await GoogleSignInService().signIn();
                                      final session = await ref.read(
                                        loginWithGoogleUseCaseProvider,
                                      )(idToken);
                                      await ref
                                          .read(authServiceProvider)
                                          .setRememberMe(true);
                                      await ref
                                          .read(sessionManagerProvider)
                                          .markActive();
                                      ref
                                          .read(authProvider.notifier)
                                          .setSession(session);
                                      if (context.mounted) {
                                        context.go(AppRoutes.home);
                                      }
                                    } on GoogleSignInConfigurationException catch (
                                      error
                                    ) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error.message.isNotEmpty
                                                  ? error.message
                                                  : 'Google sign-in is not configured for this app yet.',
                                            ),
                                          ),
                                        );
                                      }
                                    } on GoogleSignInCancelledException {
                                      return;
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Google sign-in failed. Check the Firebase app configuration and authorized OAuth client IDs, then try again.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: Icon(
                              defaultTargetPlatform == TargetPlatform.iOS
                                  ? Icons.apple
                                  : Icons.g_mobiledata,
                            ),
                            label: Text(
                              defaultTargetPlatform == TargetPlatform.iOS
                                  ? 'Continue with Apple'
                                  : 'Continue with Google',
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.forgotPassword),
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSmall),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to Farm App?',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.createAccount),
                          child: const Text('Create account'),
                        ),
                      ],
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

  Future<void> _signInWithApple() async {
    try {
      final idToken = await AppleSignInService().signIn();
      final session = await ref.read(loginWithAppleUseCaseProvider)(idToken);
      await ref.read(authServiceProvider).setRememberMe(true);
      await ref.read(sessionManagerProvider).markActive();
      ref.read(authProvider.notifier).setSession(session);
      if (mounted) context.go(AppRoutes.home);
    } on AppleSignInConfigurationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on AppleSignInCancelledException {
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Apple sign-in failed. Check the iOS capability and Firebase Apple provider settings, then try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAgreement(BuildContext context, String title) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            title == 'User Agreement'
                ? 'By using Farm App, you agree to use the app lawfully and provide accurate account and farm information. You are responsible for protecting your sign-in details. Farm information is used to provide farm management features and is handled according to the Privacy Policy. You may stop using the service at any time.'
                : 'Farm App uses account and farm information to provide farm management, support, notifications, and reporting. We use reasonable safeguards to protect this information and do not ask for your password in support messages. Contact support through the in-app customer support page for privacy questions.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
