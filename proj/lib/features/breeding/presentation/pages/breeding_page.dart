import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';
import '../../domain/entities/pregnancy.dart';
import '../providers/pregnancy_provider.dart';

class BreedingPage extends ConsumerStatefulWidget {
  const BreedingPage({super.key});

  @override
  ConsumerState<BreedingPage> createState() => _BreedingPageState();
}

class _BreedingPageState extends ConsumerState<BreedingPage> {
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _month = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(pregnancyProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeding calendar'),
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addInsemination,
        icon: const Icon(Icons.add),
        label: const Text('Record insemination'),
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'The breeding calendar could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(pregnancyProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final events = _eventsFor(items);
          final selectedEvents = events[_dateOnly(_selectedDay)] ?? [];
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pregnancyProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                Text(
                  'Plan every breeding milestone',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'See recorded inseminations, pregnancy checks and expected or actual farrowing dates.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                const _LiveBreedingOverview(),
                const SizedBox(height: 20),
                _Calendar(
                  month: _month,
                  selectedDay: _selectedDay,
                  events: events,
                  onPrevious: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  onNext: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  onSelected: (day) => setState(() => _selectedDay = day),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _dateTitle(_selectedDay),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${selectedEvents.length} milestones',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedEvents.isEmpty)
                  _EmptySchedule(onAdd: _addInsemination)
                else
                  ...selectedEvents.map((event) => _EventCard(event: event)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addInsemination() async {
    late final List<Animal> animals;
    try {
      animals = await ref.read(herdProvider.future);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load the herd: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    final femalePigs = animals
        .where(
          (animal) =>
              animal.sex.trim().toLowerCase() == 'female' &&
              animal.status == 'active',
        )
        .toList();
    if (femalePigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add an active female pig in Herd before recording insemination.',
          ),
        ),
      );
      return;
    }

    var sowId = femalePigs.first.id;
    var matingDate = _selectedDay;
    final semenController = TextEditingController();
    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Record insemination',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: sowId,
                    decoration: const InputDecoration(labelText: 'Female pig'),
                    items: femalePigs
                        .map(
                          (pig) => DropdownMenuItem(
                            value: pig.id,
                            child: Text('${pig.tag} · Pig ID ${pig.id}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheetState(() => sowId = value ?? sowId),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Insemination date'),
                    subtitle: Text(_dateTitle(matingDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                        initialDate: matingDate,
                      );
                      if (picked != null) {
                        setSheetState(() => matingDate = _dateOnly(picked));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: semenController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Semen used (optional)',
                      hintText: 'Breed, source or batch',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(
                      'Save insemination · due ${_dateTitle(matingDate.add(const Duration(days: 114)))}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref.read(pregnancyProvider.notifier).create(
        sowId: sowId,
        matingDate: matingDate,
        semenUsed: semenController.text.trim(),
        status: 'suspected',
      );
      if (!mounted) return;
      setState(() {
        _selectedDay = _dateOnly(matingDate);
        _month = DateTime(matingDate.year, matingDate.month);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insemination record saved.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save insemination: $error')),
        );
      }
    } finally {
      semenController.dispose();
    }
  }
}

Map<DateTime, List<_BreedingEvent>> _eventsFor(List<Pregnancy> records) {
  final events = <DateTime, List<_BreedingEvent>>{};
  void add(DateTime? date, Pregnancy pregnancy, _BreedingEventType type) {
    if (date == null) return;
    final key = _dateOnly(date);
    events.putIfAbsent(key, () => []).add(
      _BreedingEvent(
        sowId: pregnancy.sowId,
        sowTag: pregnancy.sowTag ?? 'Sow ${pregnancy.sowId}',
        type: type,
      ),
    );
  }

  for (final record in records) {
    add(record.matingDate, record, _BreedingEventType.mating);
    add(record.confirmationDate, record, _BreedingEventType.pregnancyCheck);
    if (record.actualFarrowingDate != null) {
      add(record.actualFarrowingDate, record, _BreedingEventType.farrowed);
    } else if (record.status != 'aborted' && record.status != 'farrowed') {
      add(record.expectedFarrowingDate, record, _BreedingEventType.farrowing);
    }
  }
  for (final dayEvents in events.values) {
    dayEvents.sort((a, b) => a.type.index.compareTo(b.type.index));
  }
  return events;
}

class _LiveBreedingOverview extends ConsumerWidget {
  const _LiveBreedingOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);

    return pregnancies.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(width: 12),
              const Expanded(child: Text('Breeding summary is unavailable.')),
              TextButton(
                onPressed: () => ref.invalidate(pregnancyProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        final active = items
            .where(
              (item) => item.status != 'farrowed' && item.status != 'aborted',
            )
            .toList();
        final dueSoon = active.where((item) => item.isDueSoon).length;
        final overdue = active.where((item) => item.isOverdue).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breeding overview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BreedingMetric(
                        label: 'Active',
                        value: active.length,
                        color: AppColors.pigPink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BreedingMetric(
                        label: 'Due soon',
                        value: dueSoon,
                        color: AppColors.warmGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BreedingMetric(
                        label: 'Overdue',
                        value: overdue,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BreedingMetric extends StatelessWidget {
  const _BreedingMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });
  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<_BreedingEvent>> events;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _monthTitle(month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((day) => Expanded(child: Center(child: Text(day))))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firstWeekday + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox();
                final day = DateTime(
                  month.year,
                  month.month,
                  index - firstWeekday + 1,
                );
                final selected = _sameDay(day, selectedDay);
                final today = _sameDay(day, DateTime.now());
                final hasEvent = events[_dateOnly(day)]?.isNotEmpty ?? false;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelected(_dateOnly(day)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          border: today && !selected
                              ? Border.all(color: AppColors.primaryGreen)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasEvent)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: CircleAvatar(
                            radius: 2,
                            backgroundColor: AppColors.pigPink,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 36,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 10),
          const Text('No insemination events scheduled'),
          TextButton(onPressed: onAdd, child: const Text('Set an event')),
        ],
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final _BreedingEvent event;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: event.type.color.withValues(alpha: .15),
        child: Icon(event.type.icon, color: event.type.color),
      ),
      title: Text(event.type.label),
      subtitle: Text('${event.sowTag} · Pig ID ${event.sowId}'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _BreedingEvent {
  const _BreedingEvent({
    required this.sowId,
    required this.sowTag,
    required this.type,
  });
  final String sowId;
  final String sowTag;
  final _BreedingEventType type;
}

enum _BreedingEventType { mating, pregnancyCheck, farrowing, farrowed }

extension on _BreedingEventType {
  String get label => switch (this) {
    _BreedingEventType.mating => 'Insemination recorded',
    _BreedingEventType.pregnancyCheck => 'Pregnancy confirmed',
    _BreedingEventType.farrowing => 'Expected farrowing',
    _BreedingEventType.farrowed => 'Farrowing recorded',
  };
  IconData get icon => switch (this) {
    _BreedingEventType.mating => Icons.favorite_outline,
    _BreedingEventType.pregnancyCheck => Icons.health_and_safety_outlined,
    _BreedingEventType.farrowing => Icons.event_available_outlined,
    _BreedingEventType.farrowed => Icons.pets_outlined,
  };
  Color get color => switch (this) {
    _BreedingEventType.mating => AppColors.pigPink,
    _BreedingEventType.pregnancyCheck => AppColors.primaryGreen,
    _BreedingEventType.farrowing => AppColors.warmGold,
    _BreedingEventType.farrowed => AppColors.info,
  };
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
String _monthTitle(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _dateTitle(DateTime value) =>
    '${const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][value.weekday % 7]}, ${value.day} ${_monthTitle(value).split(' ').first}';
