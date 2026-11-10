import 'package:flutter/material.dart';
import 'permission_icon.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PermissionIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(description),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    ),
  );
}
