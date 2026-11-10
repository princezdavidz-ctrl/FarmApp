import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../data/feed_api.dart';
import '../../data/feed_schedule_local_data_source.dart';
import '../../data/feed_reminder_service.dart';
import '../providers/feed_provider.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final schedule = ref.watch(feedScheduleProvider);
    final currency =
        ref.watch(userPreferencesProvider).valueOrNull?.currency ?? 'KES';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Management'),
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            tooltip: 'Search feed',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(feed.valueOrNull),
          ),
          Badge(
            smallSize: 8,
            child: IconButton(
              tooltip: 'Feed alerts',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => _showAlerts(feed.valueOrNull),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'feed-stock',
            onPressed: () => context.go(AppRoutes.inventory),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Feed stock'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'record-feeding',
            onPressed: feed.valueOrNull == null
                ? null
                : () => _showUsageDialog(feed.valueOrNull!),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Record feeding'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(feedProvider),
        ),
        data: (snapshot) => _Dashboard(
          snapshot: snapshot,
          schedule:
              schedule.valueOrNull ?? FeedScheduleLocalDataSource.defaults,
          currency: currency,
          onScheduleChanged: (entry, value) async {
            try {
              await ref
                  .read(feedScheduleProvider.notifier)
                  .setCompleted(entry.id, value);
              if (value && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${entry.name} marked complete')),
                );
              }
            } catch (error) {
              _showScheduleError(error);
            }
          },
          onReminderChanged: (entry, value) async {
            try {
              await ref
                  .read(feedScheduleProvider.notifier)
                  .setReminder(entry.id, value);
            } catch (error) {
              _showScheduleError(error);
            }
          },
          onEditSchedule: _editSchedule,
          onDeleteSchedule: (entry) async {
            final entries = ref.read(feedScheduleProvider).valueOrNull;
            if (entries == null) return;
            try {
              await ref
                  .read(feedScheduleProvider.notifier)
                  .saveEntries(
                    entries.where((item) => item.id != entry.id).toList(),
                  );
            } catch (error) {
              _showScheduleError(error);
            }
          },
        ),
      ),
    );
  }

  void _showScheduleError(Object error) {
    if (!mounted) return;
    final message = error is FeedReminderPermissionDenied
        ? 'Allow notifications in system settings to enable feeding reminders.'
        : 'Could not update feeding schedule: $error';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editSchedule(FeedScheduleEntry? entry) async {
    final nameController = TextEditingController(text: entry?.name ?? '');
    var time = entry == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(hour: entry.hour, minute: entry.minute);
    try {
      final result = await showDialog<({String name, TimeOfDay time})>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              entry == null ? 'Add feeding time' : 'Edit feeding time',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Feeding name'),
                  maxLength: 40,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Time'),
                  trailing: TextButton.icon(
                    onPressed: () async {
                      final selected = await showTimePicker(
                        context: dialogContext,
                        initialTime: time,
                      );
                      if (selected != null) {
                        setDialogState(() => time = selected);
                      }
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(time.format(context)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogContext, (name: name, time: time));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      final entries = ref.read(feedScheduleProvider).valueOrNull;
      if (entries == null) return;
      final minutes = result.time.hour * 60 + result.time.minute;
      final replacement =
          (entry ??
                  FeedScheduleEntry(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: result.name,
                    minutesAfterMidnight: minutes,
                  ))
              .copyWith(name: result.name, minutesAfterMidnight: minutes);
      final updated = entry == null
          ? [...entries, replacement]
          : entries
                .map((item) => item.id == entry.id ? replacement : item)
                .toList();
      try {
        await ref.read(feedScheduleProvider.notifier).saveEntries(updated);
      } catch (error) {
        _showScheduleError(error);
      }
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _showUsageDialog(FeedSnapshot snapshot) async {
    if (snapshot.stock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add feed stock before recording feeding.'),
        ),
      );
      return;
    }
    final quantity = TextEditingController();
    String stockId = snapshot.stock.first.id;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Record feeding'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: stockId,
                decoration: const InputDecoration(labelText: 'Feed type'),
                items: [
                  for (final item in snapshot.stock)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => stockId = value ?? stockId,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount fed'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(quantity.text) ?? 0;
                if (amount <= 0) return;
                final stock = snapshot.stock.firstWhere(
                  (item) => item.id == stockId,
                );
                try {
                  await ref
                      .read(feedProvider.notifier)
                      .recordUsage(
                        stockId: stockId,
                        quantity: amount,
                        unit: stock.unit,
                        usedAt: DateTime.now(),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Record'),
            ),
          ],
        ),
      );
    } finally {
      quantity.dispose();
    }
  }

  void _showSearch(FeedSnapshot? snapshot) {
    showSearch<void>(
      context: context,
      delegate: _FeedSearchDelegate(snapshot?.stock ?? const []),
    );
  }

  void _showAlerts(FeedSnapshot? snapshot) {
    final low =
        snapshot?.stock.where((item) => item.quantity <= 50).toList() ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feed alerts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _AlertRow(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              title: low.isEmpty
                  ? 'No low-stock feeds'
                  : '${low.length} feed type${low.length == 1 ? '' : 's'} running low',
              detail: low.isEmpty
                  ? 'Inventory is above the 50 kg reorder level.'
                  : low.map((item) => item.name).join(', '),
            ),
            const _AlertRow(
              icon: Icons.event_busy_rounded,
              color: AppColors.danger,
              title: 'Expiry dates need tracking',
              detail: 'Add expiry dates when this inventory data is available.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.snapshot,
    required this.schedule,
    required this.currency,
    required this.onScheduleChanged,
    required this.onReminderChanged,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  final FeedSnapshot snapshot;
  final List<FeedScheduleEntry> schedule;
  final String currency;
  final void Function(FeedScheduleEntry, bool) onScheduleChanged;
  final void Function(FeedScheduleEntry, bool) onReminderChanged;
  final void Function(FeedScheduleEntry?) onEditSchedule;
  final void Function(FeedScheduleEntry) onDeleteSchedule;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late final PageController _pageController;
  int _selectedSlide = 0;

  static const _slides = [
    ('Today', Icons.schedule_rounded),
    ('Consumption', Icons.restaurant_rounded),
    ('Analytics', Icons.insights_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSlide(int index) {
    setState(() => _selectedSlide = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final schedule = widget.schedule;
    final usedToday = snapshot.usage
        .where((item) => _isToday(item.usedAt))
        .fold<double>(0, (sum, item) => sum + item.quantity);
    final usageUnit = _usageUnit(snapshot.usage, snapshot.stock);
    final nextSchedule = _nextScheduleName(schedule);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              for (var index = 0; index < _slides.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _SlideSelector(
                      label: _slides[index].$1,
                      icon: _slides[index].$2,
                      selected: index == _selectedSlide,
                      onTap: () => _selectSlide(index),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _selectedSlide = index),
            children: [
              _FeedSlide(
                title: 'Feeding schedule',
                subtitle: 'Today’s feeding times and completion.',
                child: _ScheduleCard(
                  values: schedule,
                  highlightedName: nextSchedule,
                  onChanged: widget.onScheduleChanged,
                  onReminderChanged: widget.onReminderChanged,
                  onEdit: widget.onEditSchedule,
                  onDelete: widget.onDeleteSchedule,
                  onAdd: () => widget.onEditSchedule(null),
                ),
              ),
              _FeedSlide(
                title: 'Daily consumption',
                subtitle: 'Feed used and recorded today.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryGrid(
                      metrics: [
                        _Metric(
                          'Used today',
                          _quantity(usedToday),
                          usageUnit,
                          Icons.restaurant_rounded,
                          AppColors.aqua,
                        ),
                        _Metric(
                          'Monthly feed cost',
                          snapshot.hasMonthlyFeedCost
                              ? '${widget.currency} ${snapshot.monthlyFeedCost.toStringAsFixed(2)}'
                              : '—',
                          snapshot.hasMonthlyFeedCost
                              ? 'since the start of this month'
                              : 'add unit costs to feed stock',
                          Icons.payments_rounded,
                          AppColors.violet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DailyConsumption(usage: snapshot.usage),
                  ],
                ),
              ),
              _FeedSlide(
                title: 'Feed analytics',
                subtitle: 'Consumption trends over the last 7 days.',
                child: _AnalyticsCard(usage: snapshot.usage),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlideSelector extends StatelessWidget {
  const _SlideSelector({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.primaryGreen : AppColors.mutedText,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.deepGreen : AppColors.mutedText,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedSlide extends StatelessWidget {
  const _FeedSlide({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    key: PageStorageKey<String>(title),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
      ),
      const SizedBox(height: 20),
      child,
    ],
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.note, this.icon, this.color);
  final String label, value, note;
  final IconData icon;
  final Color color;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.metrics});
  final List<_Metric> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = (box.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: _SummaryCard(metric: metric),
            ),
        ],
      );
    },
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, size: 20, color: metric.color),
          ),
          const SizedBox(height: 14),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            metric.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.values,
    required this.highlightedName,
    required this.onChanged,
    required this.onReminderChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });
  final List<FeedScheduleEntry> values;
  final String? highlightedName;
  final void Function(FeedScheduleEntry, bool) onChanged;
  final void Function(FeedScheduleEntry, bool) onReminderChanged;
  final ValueChanged<FeedScheduleEntry> onEdit;
  final ValueChanged<FeedScheduleEntry> onDelete;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final items = [...values]
      ..sort(
        (first, second) =>
            first.minutesAfterMidnight.compareTo(second.minutesAfterMidnight),
      );
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _ScheduleRow(
              entry: items[index],
              checked: items[index].completed,
              highlighted: items[index].name == highlightedName,
              onChanged: (value) => onChanged(items[index], value),
              onReminderChanged: (value) =>
                  onReminderChanged(items[index], value),
              onEdit: () => onEdit(items[index]),
              onDelete: () => onDelete(items[index]),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No feeding times yet. Add your daily schedule.'),
            ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add feeding time'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.entry,
    required this.checked,
    required this.highlighted,
    required this.onChanged,
    required this.onReminderChanged,
    required this.onEdit,
    required this.onDelete,
  });
  final FeedScheduleEntry entry;
  final bool checked;
  final bool highlighted;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: entry.hour,
      minute: entry.minute,
    ).format(context);
    return Container(
      decoration: BoxDecoration(
        color: checked
            ? AppColors.successContainer.withValues(alpha: .45)
            : highlighted
            ? AppColors.warningContainer.withValues(alpha: .55)
            : null,
        border: highlighted
            ? Border.all(color: AppColors.warmGold.withValues(alpha: .5))
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: checked
                      ? AppColors.successContainer
                      : highlighted
                      ? AppColors.warningContainer
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  checked ? Icons.check_rounded : Icons.schedule_rounded,
                  color: checked
                      ? AppColors.success
                      : highlighted
                      ? AppColors.warning
                      : AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: highlighted ? AppColors.deepGreen : null,
                        fontWeight: highlighted ? FontWeight.w700 : null,
                      ),
                    ),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (highlighted && !checked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Edit feeding time',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('Phone reminder')),
                Switch(
                  value: entry.remindersEnabled,
                  onChanged: onReminderChanged,
                ),
                const SizedBox(width: 4),
                const Text('Done'),
                Checkbox(
                  value: checked,
                  onChanged: (value) => onChanged(value ?? false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyConsumption extends StatelessWidget {
  const _DailyConsumption({required this.usage});
  final List<FeedUsage> usage;
  @override
  Widget build(BuildContext context) {
    final today = usage.where((item) => _isToday(item.usedAt)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: today.isEmpty
            ? const Text('No feed consumption has been recorded today.')
            : Column(
                children: [
                  for (final item in today) _ConsumptionRow(item: item),
                ],
              ),
      ),
    );
  }
}

class _ConsumptionRow extends StatelessWidget {
  const _ConsumptionRow({required this.item});
  final FeedUsage item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        const Icon(Icons.water_drop_outlined, size: 19, color: AppColors.aqua),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.notes?.isNotEmpty == true ? item.notes! : 'Unassigned pen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                item.feedName ?? 'Recorded feeding',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
        Text(
          '${_quantity(item.quantity)} ${item.unit}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.usage});
  final List<FeedUsage> usage;
  @override
  Widget build(BuildContext context) {
    final values = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      return usage
          .where(
            (item) =>
                item.usedAt.year == day.year &&
                item.usedAt.month == day.month &&
                item.usedAt.day == day.day,
          )
          .fold<double>(0, (sum, item) => sum + item.quantity);
    });
    final max = values.fold<double>(
      1,
      (current, value) => value > current ? value : current,
    );
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consumption', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < 7; index++)
                    Expanded(
                      child: _ChartBar(
                        value: values[index] / max,
                        label: labels[index],
                        active: index == 6,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.value,
    required this.label,
    required this.active,
  });
  final double value;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 16,
            height: (value * 80).clamp(4, 80),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryGreen
                  : AppColors.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? AppColors.primaryGreen : AppColors.mutedText,
        ),
      ),
    ],
  );
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final Color color;
  final String title, detail;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(detail),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.danger,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load feed data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FeedSearchDelegate extends SearchDelegate<void> {
  _FeedSearchDelegate(this.stock);
  final List<FeedStock> stock;
  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() {
    final matches = stock
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (matches.isEmpty) {
      return const Center(child: Text('No matching feed found'));
    }
    return ListView(
      children: [
        for (final item in matches)
          ListTile(
            leading: const Icon(Icons.grass_rounded),
            title: Text(item.name),
            subtitle: Text(
              '${_quantity(item.quantity)} ${item.unit} available',
            ),
          ),
      ],
    );
  }
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
String _stockUnit(List<FeedStock> stock) => stock.isEmpty
    ? 'kg'
    : stock.map((item) => item.unit).toSet().length == 1
    ? stock.first.unit
    : 'mixed units';
String _usageUnit(List<FeedUsage> usage, List<FeedStock> stock) =>
    usage.isNotEmpty ? usage.first.unit : _stockUnit(stock);
String? _nextScheduleName(List<FeedScheduleEntry> entries) {
  final schedule = [...entries]
    ..sort(
      (first, second) =>
          first.minutesAfterMidnight.compareTo(second.minutesAfterMidnight),
    );
  final now = DateTime.now();
  final currentMinutes = now.hour * 60 + now.minute;
  for (final entry in schedule) {
    if (!entry.completed && entry.minutesAfterMidnight <= currentMinutes) {
      return entry.name;
    }
  }
  return schedule.where((entry) => !entry.completed).firstOrNull?.name;
}

bool _isToday(DateTime value) {
  final now = DateTime.now();
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}
