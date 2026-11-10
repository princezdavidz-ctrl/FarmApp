import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CrmPage extends ConsumerWidget {
  const CrmPage({super.key});

  static const _crmUrl = String.fromEnvironment(
    'CRM_URL',
    defaultValue: 'https://crm.example.invalid',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final farm = session?.selectedFarm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer relationships'),
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 38,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Open Farm App CRM',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      farm == null
                          ? 'Sign in to the CRM to manage customer relationships, orders, and follow-ups.'
                          : 'Continue to the CRM to manage customer relationships and follow-ups for ${farm.name}. Sign in with your Farm App account.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _openCrm(context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open CRM'),
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

  Future<void> _openCrm(BuildContext context) async {
    final uri = Uri.tryParse(_crmUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _showMessage(context, 'The CRM address is not configured correctly.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showMessage(context, 'Could not open the CRM on this device.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Could not open the CRM on this device.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
