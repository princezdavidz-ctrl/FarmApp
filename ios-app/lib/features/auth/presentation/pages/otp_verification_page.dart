import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_providers.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.challengeId,
    required this.destination,
    required this.rememberMe,
  });

  final String challengeId;
  final String destination;
  final bool rememberMe;

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _resending = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  late String _challengeId;
  late String _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _destination = widget.destination;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _submitting ||
        _resending) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await ref.read(verifyLoginOtpUseCaseProvider)(
        _challengeId,
        _otpController.text.trim(),
      );
      await ref.read(authServiceProvider).setRememberMe(widget.rememberMe);
      await ref.read(sessionManagerProvider).markActive();
      ref.read(authProvider.notifier).setSession(session);
      if (mounted) context.go(AppRoutes.home);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'That code is invalid or expired. Request a new sign-in code and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_submitting || _resending || _resendSeconds > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(resendLoginOtpUseCaseProvider)(
        _challengeId,
      );
      if (!mounted) return;
      setState(() {
        _challengeId = challenge.id;
        _destination = challenge.destination;
        _otpController.clear();
        _resendSeconds = 30;
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _resendSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _resendSeconds = 0);
          return;
        }
        setState(() => _resendSeconds--);
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('OTP verification')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit code sent to ${_destination.isEmpty ? 'your registered email' : _destination}.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (code.isEmpty) return 'Enter the OTP code';
                  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _submitting || _resending ? null : _verify,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify and sign in'),
              ),
              TextButton(
                onPressed: _submitting || _resending || _resendSeconds > 0
                    ? null
                    : _resend,
                child: Text(
                  _resending
                      ? 'Sending code…'
                      : _resendSeconds > 0
                      ? 'Resend code in ${_resendSeconds}s'
                      : 'Didn’t receive a code? Resend',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
