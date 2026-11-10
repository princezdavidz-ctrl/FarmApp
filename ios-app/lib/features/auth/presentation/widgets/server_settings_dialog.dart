import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/storage/secure_storage.dart';
import '../providers/auth_providers.dart';

/// Lets the user point the app at a different backend (LAN IP, tunnel, or domain)
/// so it keeps working when the device changes network.
Future<void> showServerSettingsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentUrl = await ref.read(serverUrlProvider.future);
  if (!context.mounted) return;
  final controller = TextEditingController(text: currentUrl);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Point the app at your farm server. Use this when switching networks.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'API base URL',
              hintText: ApiConfig.baseUrl,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ServerAddressStorage.write(null);
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          },
          child: const Text('Reset to default'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await ServerAddressStorage.write(controller.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (saved == true) ref.invalidate(serverUrlProvider);
}
