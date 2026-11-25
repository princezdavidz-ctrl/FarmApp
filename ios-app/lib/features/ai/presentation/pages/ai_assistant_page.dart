import 'package:flutter/material.dart';

import '../../../../shared/components/bottom_navigation.dart';

class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Open menu',
        icon: const Icon(Icons.menu),
        onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
      ),
      title: const Row(
        children: [
          Icon(Icons.smart_toy_outlined),
          SizedBox(width: 10),
          Text('Farm AI'),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 18),
        CircleAvatar(
          radius: 38,
          backgroundColor: Colors.green.withValues(alpha: 0.12),
          child: const Icon(Icons.auto_awesome, size: 38, color: Colors.green),
        ),
        const SizedBox(height: 20),
        Text('Your farming assistant', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Get help understanding farm records, planning activities and finding practical guidance. AI chat connection will be enabled when the FarmApp AI service is integrated.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Things you will be able to ask', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                _PromptRow(text: 'How can I improve farm productivity?'),
                _PromptRow(text: 'Help me understand my production records.'),
                _PromptRow(text: 'What should I include in today’s farm plan?'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.chat_bubble_outline, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
