import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import 'package:proj/app/theme/app_colors.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(forgotPasswordUseCaseProvider)(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not send reset link. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot password')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your account email and we will send you a reset link.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Enter a valid email.'
                  : null,
            ),
            if (_sent) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email has been sent',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'If this address is registered, a password reset link is on its way. Check your inbox and spam folder.',
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (_sent)
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Back to sign in'),
              )
            else
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send reset link'),
              ),
          ],
        ),
      ),
    ),
  );
}
