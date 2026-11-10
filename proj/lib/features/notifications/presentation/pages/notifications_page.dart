import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/notifications_api.dart';
import '../providers/notifications_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Message customer support',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => _showMessageComposer(context, ref),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _LoadFailure(onRetry: () => ref.invalidate(notificationsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: items.isEmpty
              ? const _EmptyNotifications()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _NotificationTile(
                    notification: items[index],
                    onOpen: () async {
                      if (items[index].isRead) return;
                      await ref
                          .read(notificationsProvider.notifier)
                          .markAsRead(items[index].id);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showMessageComposer(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Message customer support'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 5,
            maxLength: 1000,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Ask our customer support team for help...',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Write a message first.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref
                    .read(notificationsProvider.notifier)
                    .sendMessage(controller.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to customer support.')),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onOpen});

  final FarmNotification notification;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.severity) {
      'warning' => AppColors.warning,
      'danger' => AppColors.danger,
      'success' => AppColors.success,
      _ => AppColors.info,
    };
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      SizedBox(height: 160),
      Icon(Icons.notifications_none_outlined, size: 48),
      SizedBox(height: 16),
      Center(child: Text('No notifications yet.')),
    ],
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  );
}
