import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proj/app/routes/app_routes.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';

class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        // Help & Support
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                _SupportTile(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  subtitle: 'Browse FAQs and guides',
                  onTap: () => context.go(AppRoutes.about),
                ),
                const Divider(),
                _SupportTile(
                  icon: Icons.chat_outlined,
                  title: 'Contact Support',
                  subtitle: 'Get in touch with our support team',
                  onTap: () => context.go(AppRoutes.support),
                ),
                const Divider(),
                _SupportTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'Help us improve FarmApp',
                  onTap: () => context.go(AppRoutes.support),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        // Legal
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppDimensions.spacingMedium),
                _SupportTile(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _openLink(
                    context,
                    Uri.parse('https://example.invalid/privacy'),
                    'privacy policy',
                  ),
                ),
                const Divider(),
                _SupportTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Our terms of service',
                  onTap: () => _openLink(
                    context,
                    Uri.parse('https://example.invalid/terms'),
                    'terms and conditions',
                  ),
                ),
                const Divider(),
                _SupportTile(
                  icon: Icons.verified_user_outlined,
                  title: 'License Information',
                  subtitle: 'Open source licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'FarmApp',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        // About
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About FarmApp',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AboutRow(label: 'App Version', value: '1.0.0'),
                    const SizedBox(height: 8),
                    _AboutRow(label: 'Build Number', value: '1'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _openLink(
                            context,
                            Uri.parse('https://example.invalid'),
                            'FarmApp website',
                          );
                        },
                        icon: const Icon(Icons.update),
                        label: const Text('Visit website for updates'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        // Additional Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FarmApp',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'A comprehensive farm management platform for farmers. '
                  'Manage herd health, insemination, feed, growth tracking, sales, and more.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
      ],
    );
  }

  Future<void> _openLink(
    BuildContext context,
    Uri uri,
    String description,
  ) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted && !opened) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $description.')));
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $description: $error')),
        );
      }
    }
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}
