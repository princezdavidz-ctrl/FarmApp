import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';

class BreedingPage extends ConsumerStatefulWidget {
  const BreedingPage({super.key});

  @override
  ConsumerState<BreedingPage> createState() => _BreedingPageState();
}

class _BreedingPageState extends ConsumerState<BreedingPage> {
  late DateTime _month;
  late DateTime _selectedDay;
  final Map<DateTime, List<_BreedingEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _month = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Insemination calendar'),
      leading: IconButton(
        tooltip: 'Open menu',
        icon: const Icon(Icons.menu),
        onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addEvent,
      icon: const Icon(Icons.add),
      label: const Text('Set event'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Text(
          'Plan every insemination milestone',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Set insemination, pregnancy-check, and farrowing dates for your herd.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 18),
        _BreedingOverviewCard(pregnant: 12, dueSoon: 4, vaccinated: 48),
        const SizedBox(height: 20),
        _Calendar(
          month: _month,
          selectedDay: _selectedDay,
          events: _events,
          onPrevious: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          onSelected: (day) => setState(() => _selectedDay = day),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _dateTitle(_selectedDay),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if ((_events[_selectedDay] ?? []).isEmpty)
          _EmptySchedule(onAdd: _addEvent)
        else
          ..._events[_selectedDay]!.map(
            (event) => _EventCard(
              event: event,
              onDelete: () =>
                  setState(() => _events[_selectedDay]!.remove(event)),
            ),
          ),
      ],
    ),
  );

  Future<void> _addEvent() async {
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
            'Add an active female pig in Herd before scheduling an insemination event.',
          ),
        ),
      );
      return;
    }
    var date = _selectedDay;
    var type = _BreedingEventType.mating;
    var sowId = femalePigs.first.id;
    final event = await showModalBottomSheet<_BreedingEvent>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set insemination event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: sowId,
                decoration: const InputDecoration(
                  labelText: 'Female pig (Pig ID)',
                ),
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
              DropdownButtonFormField<_BreedingEventType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Event type'),
                items: _BreedingEventType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setSheetState(() => type = value ?? type),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: date,
                  );
                  if (picked != null) {
                    setSheetState(() => date = _dateOnly(picked));
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Date: ${_dateTitle(date)}'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _BreedingEvent(
                      sowId: sowId,
                      sowTag: femalePigs
                          .firstWhere((pig) => pig.id == sowId)
                          .tag,
                      type: type,
                    ),
                  ),
                  child: const Text('Save event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (event == null || !mounted) return;
    setState(() {
      _selectedDay = date;
      _month = DateTime(date.year, date.month);
      _events.putIfAbsent(date, () => []).add(event);
    });
  }
}

class _BreedingOverviewCard extends StatelessWidget {
  const _BreedingOverviewCard({
    required this.pregnant,
    required this.dueSoon,
    required this.vaccinated,
  });

  final int pregnant;
  final int dueSoon;
  final int vaccinated;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Metric(label: 'Pregnant', value: '$pregnant', color: AppColors.pigPink),
      _Metric(label: 'Due soon', value: '$dueSoon', color: AppColors.warmGold),
      _Metric(label: 'Vaccinated', value: '$vaccinated', color: AppColors.info),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insemination overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: items
                  .map(
                    (item) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.value,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
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
  const _EventCard({required this.event, required this.onDelete});
  final _BreedingEvent event;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: event.type.color.withValues(alpha: .15),
        child: Icon(event.type.icon, color: event.type.color),
      ),
      title: Text(event.type.label),
      subtitle: Text('${event.sowTag} · Pig ID ${event.sowId}'),
      trailing: IconButton(onPressed: onDelete, icon: const Icon(Icons.close)),
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

enum _BreedingEventType { mating, pregnancyCheck, farrowing }

extension on _BreedingEventType {
  String get label => switch (this) {
    _BreedingEventType.mating => 'Insemination',
    _BreedingEventType.pregnancyCheck => 'Pregnancy check',
    _BreedingEventType.farrowing => 'Expected farrowing',
  };
  IconData get icon => switch (this) {
    _BreedingEventType.mating => Icons.favorite_outline,
    _BreedingEventType.pregnancyCheck => Icons.health_and_safety_outlined,
    _BreedingEventType.farrowing => Icons.child_friendly_outlined,
  };
  Color get color => switch (this) {
    _BreedingEventType.mating => AppColors.pigPink,
    _BreedingEventType.pregnancyCheck => AppColors.primaryGreen,
    _BreedingEventType.farrowing => AppColors.warmGold,
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
