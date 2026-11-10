import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    required this.onSubmit,
    this.canSubmit = true,
    this.useOtp = false,
    this.onOtpToggle,
    this.onSendOtp,
    super.key,
  });

  final Future<void> Function(String email, String password, bool rememberMe)
  onSubmit;
  final bool canSubmit;
  final bool useOtp;
  final VoidCallback? onOtpToggle;
  final Future<void> Function(String email)? onSendOtp;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool rememberMe = false;
  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      children: [
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email or phone number',
            hintText: 'you@example.com or phone number',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          validator: (value) {
            final input = value?.trim() ?? '';
            if (input.isEmpty) {
              return 'Enter your email or phone number';
            }

            final validPhone = RegExp(r'^\+?[0-9\s-]{8,}$').hasMatch(input);
            final validEmail = RegExp(
              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
            ).hasMatch(input);
            if (!validEmail && !validPhone) {
              return 'Enter a valid email or phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          obscureText: !passwordVisible,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: passwordVisible ? 'Hide password' : 'Show password',
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => passwordVisible = !passwordVisible),
            ),
          ),
          validator: (value) {
            final input = value?.trim() ?? '';
            if (input.isEmpty) {
              return 'Enter your password';
            }
            return null;
          },
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: CheckboxListTile(
            value: rememberMe,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onChanged: (value) => setState(() => rememberMe = value ?? false),
            title: const Text('Remember me'),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading || !widget.canSubmit
                ? null
                : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setState(() => isLoading = true);
                    try {
                      await widget.onSubmit(
                        emailController.text.trim(),
                        passwordController.text,
                        rememberMe,
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to sign in. Please try again.',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  },
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Sign in',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    ),
  );
}
