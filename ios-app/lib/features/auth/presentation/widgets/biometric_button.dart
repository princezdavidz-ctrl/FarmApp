import 'package:flutter/material.dart';

class BiometricButton extends StatelessWidget {
  const BiometricButton({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onPressed, icon: const Icon(Icons.fingerprint), label: const Text('Use biometrics'));
}
