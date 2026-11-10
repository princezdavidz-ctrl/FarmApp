import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({required this.farmId, super.key});

  final String farmId;

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  final _messageController = TextEditingController();
  Map<String, dynamic>? _conversation;
  bool _loading = true;
  bool _sending = false;
  bool? _supportOnline;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _loadPresence();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadConversation(silent: true);
      _loadPresence();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = ref.read(notificationsApiProvider);
      final conversation = await api.fetchSupportConversation(widget.farmId);
      if (!mounted) return;
      _conversation = conversation;
      if (conversation != null)
        await api.markSupportConversationRead(widget.farmId);
    } catch (error) {
      if (mounted && !silent) _error = error.toString();
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadPresence() async {
    try {
      final online = await ref
          .read(notificationsApiProvider)
          .fetchSupportPresence(widget.farmId);
      if (mounted) setState(() => _supportOnline = online);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not check agent availability: $error');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(notificationsProvider.notifier).sendMessage(message);
      if (!mounted) return;
      _messageController.clear();
      await _loadConversation();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = (_conversation?['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final agent = _conversation?['assigned_agent'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryGreen,
              child: Icon(Icons.support_agent, color: Colors.white, size: 19),
            ),
            SizedBox(width: 10),
            Text('Customer Care'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: _loading ? null : _loadConversation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (agent != null)
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  'Speaking with ${agent['name'] ?? 'Customer Support'}',
                ),
                subtitle: Text('${agent['role'] ?? 'Customer support'}'),
              )
            else
              ListTile(
                leading: Icon(
                  _supportOnline == true ? Icons.circle : Icons.circle_outlined,
                  color: _supportOnline == true ? Colors.green : null,
                ),
                title: const Text('Farm App Customer Support'),
                subtitle: Text(
                  _supportOnline == true
                      ? 'An agent is online. Your message will be routed to an available person.'
                      : 'No agents are online right now. Your message will be queued for the next available agent.',
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadConversation,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _supportOnline == true
                              ? 'Send a message to start a conversation with customer support.'
                              : 'Send a message and customer support will reply when an agent is available.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final fromSupport = message['sender_role'] == 'crm';
                        return Align(
                          alignment: fromSupport
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 340),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: fromSupport
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest
                                  : AppColors.deepGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${message['sender_name'] ?? (fromSupport ? 'Customer Support' : 'You')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: fromSupport ? null : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${message['body'] ?? ''}',
                                  style: TextStyle(
                                    color: fromSupport ? null : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Material(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message customer support',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
