import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes/app_routes.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _expandedMission = true;
  bool _expandedCompany = false;
  bool _expandedContact = false;
  bool _expandedLegal = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About FarmApp'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          // Header with Logo and Tagline
          _HeaderSection(),
          const SizedBox(height: AppDimensions.spacingLarge),

          // Mission Section
          _ExpandableSection(
            title: 'Our Mission',
            icon: Icons.lightbulb_outline,
            isExpanded: _expandedMission,
            onTap: () => setState(() => _expandedMission = !_expandedMission),
            child: Text(
              'FarmApp helps farmers manage their farms, improve productivity, and make confident decisions with practical digital tools.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),

          // Company Section
          _ExpandableSection(
            title: 'About Company',
            icon: Icons.business,
            isExpanded: _expandedCompany,
            onTap: () => setState(() => _expandedCompany = !_expandedCompany),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LogiHost Technologies Ltd',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Location: Nairobi, Kenya',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'We provide comprehensive farm management solutions that integrate modern technology with agricultural best practices to empower farmers across Africa.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),

          // Contact Section
          _ExpandableSection(
            title: 'Contact Us',
            icon: Icons.contact_support_outlined,
            isExpanded: _expandedContact,
            onTap: () => setState(() => _expandedContact = !_expandedContact),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('In-app customer support'),
                  subtitle: const Text(
                    'Chat with our support team in the app.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.go(AppRoutes.support),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Website'),
                  subtitle: const Text('example.invalid'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openWebsite(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),

          // Legal Section
          _ExpandableSection(
            title: 'Legal & Policies',
            icon: Icons.policy_outlined,
            isExpanded: _expandedLegal,
            onTap: () => setState(() => _expandedLegal = !_expandedLegal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegalLink(
                  title: 'Privacy Policy',
                  onTap: () => _showLegal(context, 'Privacy Policy'),
                ),
                const SizedBox(height: 12),
                _LegalLink(
                  title: 'Terms & Conditions',
                  onTap: () => _showLegal(context, 'Terms & Conditions'),
                ),
                const SizedBox(height: 12),
                _LegalLink(
                  title: 'Open Source Licenses',
                  onTap: () => _showLegal(context, 'Open Source Licenses'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),

          // App Info Section
          _AppInfoSection(),
          const SizedBox(height: AppDimensions.spacingLarge),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  '© 2026 LogiHost Technologies Ltd',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'All rights reserved.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showLegal(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(_getLegalContent(title))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getLegalContent(String title) {
    switch (title) {
      case 'Privacy Policy':
        return 'FarmApp Privacy Policy\n\n'
            'Last Updated: 2026\n\n'
            'Your privacy is important to us. We are committed to being transparent about the data we collect and how we use it.\n\n'
            'Data Collection: We collect information about your farm operations to provide better service.\n\n'
            'Data Usage: Your data is used to provide analytics, reports, and insights.\n\n'
            'Security: We implement industry-standard security measures to protect your data.\n\n'
            'For more information, visit https://example.invalid/privacy';
      case 'Terms & Conditions':
        return 'FarmApp User Agreement\n\n'
            'Last Updated: 2026\n\n'
            'By using FarmApp, you agree to these terms and conditions.\n\n'
            'License: We grant you a limited license to use FarmApp for your farm management activities.\n\n'
            'Restrictions: You may not modify, copy, or distribute the app.\n\n'
            'Liability: We are not liable for any indirect damages.\n\n'
            'For more information, visit https://example.invalid/terms';
      case 'Open Source Licenses':
        return 'FarmApp Open Source Licenses\n\n'
            'FarmApp uses the following open source packages:\n\n'
            '• Riverpod 2.6.1 - Apache License 2.0\n'
            '• Dio 5.7.0 - MIT License\n'
            '• Flutter - BSD License\n'
            '• Material Design - Apache License 2.0\n\n'
            'For complete license information, visit https://example.invalid/licenses';
      default:
        return '';
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://example.invalid');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the website.')),
        );
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the website.')),
        );
      }
    }
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primaryGreen,
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: const Icon(
              Icons.agriculture,
              size: 96,
              color: Colors.white,
              semanticLabel: 'FarmApp',
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text(
            'FarmApp',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.inverseText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farm Management Platform',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inverseMutedText),
          ),
        ],
      ),
    ),
  );
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });

  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: child,
          ),
        ],
      ],
    ),
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.primaryGreen),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    ),
  );
}

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Information',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _AppInfoRow(label: 'Version', value: '1.0.0'),
          const SizedBox(height: 12),
          _AppInfoRow(label: 'Build Number', value: '1'),
          const SizedBox(height: 12),
          _AppInfoRow(label: 'Last Update', value: 'January 2026'),
          const SizedBox(height: AppDimensions.spacingMedium),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _checkForUpdates(context),
              icon: const Icon(Icons.update),
              label: const Text('Check for Updates'),
            ),
          ),
        ],
      ),
    ),
  );

  void _checkForUpdates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are using the latest version of FarmApp'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}
