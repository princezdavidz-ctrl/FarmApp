import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'support_chat_page.dart';
import '../../../notifications/data/notifications_api.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

const _supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
const _supportWhatsApp = String.fromEnvironment('SUPPORT_WHATSAPP');
const _emergencyVeterinaryPhone = String.fromEnvironment('VETERINARY_PHONE');

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final subjectController = TextEditingController();
  final descriptionController = TextEditingController();
  String selectedCategory = 'General';
  bool _submittingTicket = false;

  @override
  void dispose() {
    subjectController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> submitTicket(WidgetRef ref) async {
    if (_submittingTicket) return;
    if (subjectController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (ref.read(authProvider).valueOrNull?.selectedFarm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a farm before sending a request.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submittingTicket = true);
    try {
      final message = [
        'Support request: ${subjectController.text.trim()}',
        'Category: $selectedCategory',
        '',
        descriptionController.text.trim(),
      ].join('\n');
      await ref.read(notificationsProvider.notifier).sendMessage(message);
      if (!mounted) return;
      subjectController.clear();
      descriptionController.clear();
      setState(() => selectedCategory = 'General');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request sent. Replies will appear in Customer Care chat.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your support request. Please retry.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingTicket = false);
    }
  }

  Future<void> _openContact(Uri uri, String service) async {
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This device cannot open $service.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;
    if (launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $service on this device.')),
    );
  }

  Future<void> callVeterinary() async {
    if (_emergencyVeterinaryPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency veterinary contact is not configured.'),
        ),
      );
      return;
    }
    await _openContact(
      Uri(scheme: 'tel', path: _emergencyVeterinaryPhone),
      'the emergency veterinary line',
    );
  }

  void _openLiveChat(WidgetRef ref) {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SupportChatPage(farmId: farmId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final notifications =
            ref.watch(notificationsProvider).valueOrNull ??
            const <FarmNotification>[];
        final crmMessage = notifications.cast<FarmNotification?>().firstWhere(
          (notification) => notification?.type == 'crm_message',
          orElse: () => null,
        );
        final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
        final presence = farmId == null
            ? Future<bool>.value(false)
            : ref.read(notificationsApiProvider).fetchSupportPresence(farmId);

        return Scaffold(
          endDrawer: _SupportDrawer(
            onOpenLiveChat: () => _openLiveChat(ref),
            onCall: callVeterinary,
          ),
          appBar: AppBar(
            title: const Text('Customer Support'),
            leading: IconButton(
              tooltip: 'Back to home',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(AppRoutes.home),
            ),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Guidance and contacts',
                  icon: const Icon(Icons.menu_open),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.pagePadding,
              AppDimensions.pagePadding,
              AppDimensions.pagePadding,
              32,
            ),
            children: [
              FutureBuilder<bool>(
                future: presence,
                builder: (context, snapshot) => _SupportHeader(
                  customerCareName: 'Customer Care',
                  supportOnline: snapshot.data ?? false,
                  onEmergencyCall: callVeterinary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Text('Live chat', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppDimensions.spacingMedium),
              FutureBuilder<bool>(
                future: presence,
                builder: (context, snapshot) => _LiveChatPreview(
                  customerCareName: 'Customer Care',
                  supportOnline: snapshot.data ?? false,
                  message: crmMessage?.body,
                  onOpenChat: () => _openLiveChat(ref),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Text(
                'Contact Options',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _ContactOptionsSection(
                onOpenContact: _openContact,
                supportEmail: _supportEmail,
                whatsappNumber: _supportWhatsApp,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              _EmergencyVeterinaryCard(
                onCall: callVeterinary,
                phone: _emergencyVeterinaryPhone,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Text(
                'Frequently Asked Questions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _FAQSection(),
              const SizedBox(height: AppDimensions.spacingLarge),
              Text(
                'Submit a Ticket',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _TicketSubmissionForm(
                subjectController: subjectController,
                descriptionController: descriptionController,
                selectedCategory: selectedCategory,
                submitting: _submittingTicket,
                onCategoryChanged: (value) {
                  setState(() => selectedCategory = value ?? 'General');
                },
                onSubmit: () => submitTicket(ref),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Text(
                'User Guide & Tutorials',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _UserGuideSection(),
            ],
          ),
        );
      },
    );
  }
}

class _SupportDrawer extends StatelessWidget {
  const _SupportDrawer({required this.onOpenLiveChat, required this.onCall});

  final VoidCallback onOpenLiveChat;
  final Future<void> Function() onCall;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent_outlined,
                size: 28,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Support Center',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Open live chat'),
            onTap: () {
              Navigator.of(context).pop();
              onOpenLiveChat();
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined),
            title: const Text('Vet emergency'),
            onTap: () async {
              Navigator.of(context).pop();
              await onCall();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('FAQ'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open the FAQ section below.')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _LiveChatPreview extends StatelessWidget {
  const _LiveChatPreview({
    required this.customerCareName,
    required this.supportOnline,
    required this.message,
    required this.onOpenChat,
  });

  final String customerCareName;
  final bool supportOnline;
  final String? message;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          color: const Color(0xFFE7F6EC),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryGreen,
                child: Icon(Icons.support_agent, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerCareName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      supportOnline
                          ? 'Customer Care · online'
                          : 'Customer Care · offline',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: AppColors.primaryGreen),
            ],
          ),
        ),
        Container(
          color: const Color(0xFFF3FBF5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text('Hi there! We\'re here to help with your farm.'),
                ),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Text(message!),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Continue live chat'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Support Header Widget
class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.customerCareName,
    required this.supportOnline,
    required this.onEmergencyCall,
  });

  final String customerCareName;
  final bool supportOnline;
  final VoidCallback onEmergencyCall;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Card(
        color: AppColors.deepGreen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingLarge,
            AppDimensions.spacingLarge,
            88,
            AppDimensions.spacingLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.inverseText.withValues(
                      alpha: 0.18,
                    ),
                    child: const Icon(
                      Icons.support_agent_outlined,
                      color: AppColors.inverseText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We\'re here to help',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.inverseText),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: supportOnline
                                    ? AppColors.success
                                    : AppColors.mutedText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              supportOnline
                                  ? 'Agents online'
                                  : 'No agents online',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.inverseMutedText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerCareName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.inverseText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMedium,
                  vertical: AppDimensions.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inverseText.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
                child: Text(
                  'Average response time: 2-4 hours',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inverseText),
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: 18,
        bottom: 18,
        child: FloatingActionButton(
          heroTag: 'support-emergency-vet',
          mini: true,
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.inverseText,
          tooltip: 'Call emergency vet',
          onPressed: onEmergencyCall,
          child: const Icon(Icons.phone_in_talk_outlined),
        ),
      ),
    ],
  );
}

// Contact Options Section
class _ContactOptionsSection extends StatelessWidget {
  const _ContactOptionsSection({
    required this.onOpenContact,
    required this.supportEmail,
    required this.whatsappNumber,
  });

  final Future<void> Function(Uri uri, String service) onOpenContact;
  final String supportEmail;
  final String whatsappNumber;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (whatsappNumber.isNotEmpty)
        _ContactOptionTile(
          icon: Icons.chat_outlined,
          title: 'WhatsApp',
          subtitle: whatsappNumber,
          actionLabel: 'Open',
          onTap: () => onOpenContact(
            Uri.parse('https://wa.me/$whatsappNumber'),
            'WhatsApp',
          ),
        ),
      if (supportEmail.isNotEmpty)
        _ContactOptionTile(
          icon: Icons.email_outlined,
          title: 'Email Support',
          subtitle: supportEmail,
          actionLabel: 'Email',
          onTap: () => onOpenContact(
            Uri(
              scheme: 'mailto',
              path: supportEmail,
              queryParameters: {'subject': 'Support request'},
            ),
            'the email app',
          ),
        ),
      if (whatsappNumber.isEmpty && supportEmail.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: Text('Support contact details are not configured.'),
        ),
      Card(
        color: AppColors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMedium),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.primaryGreen),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Hours',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Text(
                      'Monday - Friday: 8:00 AM - 6:00 PM (Local Time)\nWeekends: 10:00 AM - 4:00 PM',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// Contact Option Tile
class _ContactOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _ContactOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
    ),
  );
}

// Emergency Veterinary Help Card
class _EmergencyVeterinaryCard extends StatelessWidget {
  final VoidCallback onCall;
  final String phone;

  const _EmergencyVeterinaryCard({required this.onCall, required this.phone});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.danger,
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emergency_outlined,
                color: AppColors.inverseText,
                size: 32,
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Veterinary Help',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.inverseText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      phone.isEmpty
                          ? 'Contact a local veterinarian in an emergency.'
                          : 'Urgent veterinary assistance: $phone',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inverseMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone),
              label: const Text('Call Emergency Vet Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseText,
                foregroundColor: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// FAQ Section
class _FAQSection extends StatefulWidget {
  @override
  State<_FAQSection> createState() => _FAQSectionState();
}

class _FAQSectionState extends State<_FAQSection> {
  final _faqItems = [
    {
      'category': 'Breeding',
      'question': 'How do I track breeding cycles?',
      'answer':
          'Use the Breeding section to log breeding dates, sire information, and expected due dates. The app will send notifications for important milestones.',
    },
    {
      'category': 'Vaccination',
      'question': 'How do I schedule vaccinations?',
      'answer':
          'Navigate to Health & Vaccination and add vaccination records. Set reminders for upcoming vaccinations to ensure your herd stays healthy.',
    },
    {
      'category': 'Feed',
      'question': 'How do I manage feed inventory?',
      'answer':
          'Use the Feed Management section to log feed purchases and consumption. The app will help you track feed costs and optimize inventory levels.',
    },
    {
      'category': 'Payments',
      'question': 'How do I track payments and expenses?',
      'answer':
          'All transactions are logged in the Reports section. You can filter by date, category, or animal ID for detailed financial tracking.',
    },
    {
      'category': 'Account',
      'question': 'How do I reset my password?',
      'answer':
          'Use the "Forgot Password" option on the login page. You\'ll receive an email with a reset link. If you don\'t receive it, check your spam folder.',
    },
    {
      'category': 'Account',
      'question': 'How do I change my server address?',
      'answer':
          'Open Settings from your profile menu and select "Server Settings". Enter the new server address and save.',
    },
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionPanelList.radio(
      elevation: 0,
      expandedHeaderPadding: EdgeInsets.zero,
      dividerColor: AppColors.outline,
      children: List.generate(_faqItems.length, (index) {
        final item = _faqItems[index];
        return ExpansionPanelRadio(
          canTapOnHeader: true,
          value: index,
          headerBuilder: (context, isExpanded) => ListTile(
            title: Text(item['question']!),
            subtitle: Text(
              item['category']!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.primaryGreen),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.primaryGreen,
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(item['answer']!),
          ),
        );
      }),
    ),
  );
}

// Ticket Submission Form
class _TicketSubmissionForm extends StatelessWidget {
  final TextEditingController subjectController;
  final TextEditingController descriptionController;
  final String selectedCategory;
  final bool submitting;
  final Function(String?) onCategoryChanged;
  final VoidCallback onSubmit;

  const _TicketSubmissionForm({
    required this.subjectController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.submitting,
    required this.onCategoryChanged,
    required this.onSubmit,
  });

  final _categories = const [
    'General',
    'Breeding',
    'Vaccination',
    'Feed',
    'Payments',
    'Technical Issue',
    'Other',
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            onChanged: onCategoryChanged,
            items: _categories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            decoration: const InputDecoration(
              hintText: 'Select a category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text('Subject', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: subjectController,
            decoration: const InputDecoration(
              hintText: 'Brief description of your issue',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text('Description', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Provide details about your issue',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(submitting ? 'Sending…' : 'Send Support Request'),
            ),
          ),
        ],
      ),
    ),
  );
}

// User Guide Section
class _UserGuideSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _GuideTile(
        icon: Icons.play_circle_outline,
        title: 'Getting Started',
        description: 'Learn the basics of using Farm App',
        onTap: () => _showMessage(context, 'Video tutorial loading...'),
      ),
      _GuideTile(
        icon: Icons.show_chart_outlined,
        title: 'Understanding Reports',
        description: 'Make sense of your farm data and analytics',
        onTap: () => _showMessage(context, 'Video tutorial loading...'),
      ),
      _GuideTile(
        icon: Icons.people_outline,
        title: 'Managing Team Access',
        description: 'Set up and manage farm workers and managers',
        onTap: () => _showMessage(context, 'Video tutorial loading...'),
      ),
      _GuideTile(
        icon: Icons.mediation_outlined,
        title: 'Best Practices',
        description: 'Tips for optimal farm management',
        onTap: () => _showMessage(context, 'Video tutorial loading...'),
      ),
    ],
  );
}

// Guide Tile Widget
class _GuideTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _GuideTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppDimensions.radius),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 24),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.mutedText,
            ),
          ],
        ),
      ),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
