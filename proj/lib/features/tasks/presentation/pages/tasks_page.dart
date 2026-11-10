import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../features/auth/domain/entities/session.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/settings/domain/entities/farm_member.dart';
import '../../../../features/settings/presentation/providers/farm_access_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../data/farm_task.dart';
import '../providers/farm_tasks_provider.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authProvider).valueOrNull;
    final taskState = ref.watch(farmTasksProvider);
    final accessState = ref.watch(farmAccessProvider).valueOrNull;
    final canManage = _canManageTasks(session, accessState);
    final tasks = taskState.valueOrNull ?? const <FarmTask>[];
    final openTasks = tasks.where((task) => !task.isCompleted).toList();
    final dueToday = openTasks.where((task) => _isDueToday(task.dueAt)).length;
    final highPriority = openTasks
        .where((task) => task.priority == 'high' || task.priority == 'urgent')
        .length;
    final completed = tasks.where((task) => task.isCompleted).length;
    final filtered = tasks
        .where(
          (task) => switch (_selectedFilter) {
            'today' => _isDueToday(task.dueAt),
            'high' => task.priority == 'high' || task.priority == 'urgent',
            'completed' => task.isCompleted,
            _ => true,
          },
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.farmTasks),
        leading: IconButton(
          tooltip: l10n.openMenu,
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      floatingActionButton: canManage && session?.selectedFarm != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showCreateTaskDialog(accessState?.members ?? const []),
              icon: const Icon(Icons.add_task_rounded),
              label: Text(l10n.addTask),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(farmTasksProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          children: [
            _SummaryCard(
              title: l10n.dailyFarmPlan,
              subtitle: l10n.dailyFarmPlanDescription,
              items: [
                _MetricItem(label: l10n.dueToday, value: '$dueToday'),
                _MetricItem(label: l10n.highPriority, value: '$highPriority'),
                _MetricItem(label: l10n.completed, value: '$completed'),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', l10n.allTasksFilter),
                  _filterChip('today', l10n.dueToday),
                  _filterChip('high', l10n.highPriority),
                  _filterChip('completed', l10n.completed),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            taskState.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 38),
                      const SizedBox(height: 10),
                      Text(l10n.taskLoadFailed),
                      const SizedBox(height: 8),
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(farmTasksProvider),
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) => filtered.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          AppDimensions.spacingLarge,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.task_alt_outlined,
                              size: 42,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noTasksInView,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.createTaskInstruction,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final task in filtered)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimensions.spacingMedium,
                            ),
                            child: _TaskCard(
                              task: task,
                              canManage: canManage,
                              canToggle:
                                  canManage ||
                                  task.assignedTo == session?.user.id,
                              onToggle: () => _toggleTask(task),
                              onDelete: canManage
                                  ? () => _deleteTask(task)
                                  : null,
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

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (_) => setState(() => _selectedFilter = value),
    ),
  );

  bool _canManageTasks(Session? session, FarmAccessState? access) {
    if (session?.user.role == UserRole.farmOwner) return true;
    if (session == null || access == null) return false;
    return access
        .permissionsFor(session.user.id)
        .contains(AppPermission.manageTasks);
  }

  bool _isDueToday(DateTime? date) {
    if (date == null) return false;
    final local = date.toLocal();
    final today = DateTime.now();
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }

  Future<void> _toggleTask(FarmTask task) async {
    try {
      await ref.read(farmTasksProvider.notifier).toggle(task);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _deleteTask(FarmTask task) async {
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteTaskTitle),
        content: Text(task.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ref.read(farmTasksProvider.notifier).delete(task.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showCreateTaskDialog(List<FarmMember> members) async {
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    String priority = 'normal';
    String category = 'feeding';
    String assignedTo = '';
    DateTime? dueAt;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.addFarmTask),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: l10n.taskTitle),
                      maxLength: 255,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.taskTitleRequired
                          : null,
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(labelText: l10n.taskNotes),
                      maxLines: 2,
                      maxLength: 4000,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(labelText: l10n.priority),
                      items: [
                        DropdownMenuItem(value: 'low', child: Text(l10n.low)),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text(l10n.normal),
                        ),
                        DropdownMenuItem(value: 'high', child: Text(l10n.high)),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text(l10n.urgent),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? priority),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(labelText: l10n.category),
                      items: [
                        DropdownMenuItem(
                          value: 'feeding',
                          child: Text(l10n.feeding),
                        ),
                        DropdownMenuItem(
                          value: 'health',
                          child: Text(l10n.health),
                        ),
                        DropdownMenuItem(
                          value: 'growth',
                          child: Text(l10n.growth),
                        ),
                        DropdownMenuItem(
                          value: 'sales',
                          child: Text(l10n.salesCategory),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(l10n.otherCategory),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: assignedTo,
                      decoration: InputDecoration(labelText: l10n.assignedTo),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.unassigned),
                        ),
                        for (final member in members)
                          DropdownMenuItem(
                            value: member.id,
                            child: Text(
                              member.name.isEmpty ? member.email : member.name,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => assignedTo = value ?? ''),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                          initialDate: dueAt ?? DateTime.now(),
                        );
                        if (selectedDate == null || !dialogContext.mounted) {
                          return;
                        }
                        final selectedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: dueAt == null
                              ? TimeOfDay.now()
                              : TimeOfDay.fromDateTime(dueAt!),
                        );
                        if (selectedTime != null) {
                          setDialogState(
                            () => dueAt = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        dueAt == null
                            ? l10n.due
                            : '${MaterialLocalizations.of(context).formatMediumDate(dueAt!)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dueAt!))}',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(farmTasksProvider.notifier)
                            .create(
                              title: titleController.text.trim(),
                              priority: priority,
                              category: category,
                              notes: notesController.text.trim(),
                              assignedTo: assignedTo.isEmpty
                                  ? null
                                  : assignedTo,
                              dueAt: dueAt,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error = '$exception';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveTask),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    notesController.dispose();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });
  final String title;
  final String subtitle;
  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.deepGreen,
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.inverseText),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inverseMutedText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inverseText.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppColors.inverseText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.inverseMutedText),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MetricItem {
  const _MetricItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.canManage,
    required this.canToggle,
    required this.onToggle,
    this.onDelete,
  });
  final FarmTask task;
  final bool canManage;
  final bool canToggle;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoryLabel = switch (task.category) {
      'feeding' => l10n.feeding,
      'health' => l10n.health,
      'growth' => l10n.growth,
      'sales' => l10n.salesCategory,
      _ => task.category,
    };
    final priorityColor = switch (task.priority) {
      'urgent' || 'high' => AppColors.danger,
      'normal' => AppColors.warmGold,
      _ => AppColors.success,
    };
    final priorityLabel = switch (task.priority) {
      'high' => l10n.high,
      'low' => l10n.low,
      'normal' => l10n.normal,
      _ => l10n.urgent,
    };
    final dueAt = task.dueAt?.toLocal();
    final dueLabel = dueAt == null
        ? l10n.due
        : '${MaterialLocalizations.of(context).formatMediumDate(dueAt)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dueAt))}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: canToggle ? (_) => onToggle() : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? AppColors.mutedText : null,
                    ),
                  ),
                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        label: categoryLabel,
                        color: AppColors.primaryContainer,
                      ),
                      _Pill(
                        label: priorityLabel,
                        color: priorityColor.withValues(alpha: 0.12),
                      ),
                      _Pill(label: dueLabel, color: AppColors.infoContainer),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.assignedTo}: ${task.assigneeName ?? l10n.unassigned}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage && onDelete != null)
              IconButton(
                tooltip: l10n.delete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}
