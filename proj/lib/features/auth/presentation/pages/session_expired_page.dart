import 'package:flutter/material.dart';

class SessionExpiredPage extends StatelessWidget {
  const SessionExpiredPage({required this.onSignIn, super.key});
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_clock, size: 56), const SizedBox(height: 16), Text('Session expired', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 8), const Text('Please sign in again to continue.'), const SizedBox(height: 24), FilledButton(onPressed: onSignIn, child: const Text('Sign in'))]))));
}
