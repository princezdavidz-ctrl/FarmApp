import 'package:flutter/material.dart';

class PermissionIcon extends StatelessWidget {
  const PermissionIcon({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 25,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
  );
}
