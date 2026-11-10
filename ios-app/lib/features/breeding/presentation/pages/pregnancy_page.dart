import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';
import '../../domain/entities/pregnancy.dart';
import '../providers/pregnancy_provider.dart';

class PregnancyPage extends ConsumerWidget {
  const PregnancyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pregnancy tracking')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPregnancy(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Record insemination'),
      ),
      body: pregnancies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(pregnancyProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No pregnancy records yet. Add an insemination record to begin.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pregnancyProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Summary(items: items),
                const SizedBox(height: 16),
                _PregnancyGrid(items: items),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddPregnancy(BuildContext context, WidgetRef ref) async {
    late final List<Animal> animals;
    try {
      animals = await ref.read(herdProvider.future);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load the herd: $error')),
        );
      }
      return;
    }
    if (!context.mounted) return;
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
    var matingDate = DateTime.now();
    var status = 'suspected';
    final semenController = TextEditingController();
    final litterController = TextEditingController();
    final notesController = TextEditingController();
    try {
      final result = await showModalBottomSheet<bool>(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Record insemination',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Insemination date'),
                    subtitle: Text(_date(matingDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: matingDate,
                      );
                      if (picked != null) {
                        setSheetState(() => matingDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: semenController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Semen used',
                      hintText: 'e.g. Large White, batch LW-24',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'suspected',
                        child: Text('Suspected'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'high_risk',
                        child: Text('High risk'),
                      ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => status = value ?? status),
                  ),
                  TextField(
                    controller: litterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Expected litter size',
                    ),
                  ),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(
                      'Save (due ${_date(matingDate.add(const Duration(days: 114)))})',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (result != true || !context.mounted) return;
      await ref
          .read(pregnancyProvider.notifier)
          .create(
            sowId: sowId,
            matingDate: matingDate,
            semenUsed: semenController.text,
            status: status,
            expectedLitterSize: int.tryParse(litterController.text),
            notes: notesController.text,
          );
    } finally {
      semenController.dispose();
      litterController.dispose();
      notesController.dispose();
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});
  final List<Pregnancy> items;

  @override
  Widget build(BuildContext context) {
    final active = items
        .where((item) => item.status != 'farrowed' && item.status != 'aborted')
        .length;
    final dueSoon = items.where((item) => item.isDueSoon).length;
    final overdue = items.where((item) => item.isOverdue).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Metric(label: 'Active', value: '$active'),
            _Metric(
              label: 'Due soon',
              value: '$dueSoon',
              color: AppColors.warmGold,
            ),
            _Metric(
              label: 'Overdue',
              value: '$overdue',
              color: AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _PregnancyGrid extends StatelessWidget {
  const _PregnancyGrid({required this.items});
  final List<Pregnancy> items;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 224,
    ),
    itemBuilder: (context, index) => _PregnancyCard(pregnancy: items[index]),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(color: color),
      ),
      Text(label),
    ],
  );
}

class _PregnancyCard extends StatelessWidget {
  const _PregnancyCard({required this.pregnancy});
  final Pregnancy pregnancy;
  @override
  Widget build(BuildContext context) {
    final color = pregnancy.isOverdue
        ? AppColors.danger
        : pregnancy.isDueSoon
        ? AppColors.warmGold
        : AppColors.primaryGreen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: .14),
                  child: Icon(Icons.favorite_outline, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pregnancy.sowTag ?? 'Sow ${pregnancy.sowId}',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PregnancyDetail(
              label: 'Days pregnant',
              value: '${pregnancy.daysPregnant}',
            ),
            _PregnancyDetail(
              label: 'Time remaining',
              value: pregnancy.status == 'farrowed'
                  ? 'Farrowed'
                  : pregnancy.status == 'aborted'
                  ? 'Aborted'
                  : pregnancy.isOverdue
                  ? '${-(pregnancy.daysUntilFarrowing ?? 0)} days overdue'
                  : '${pregnancy.daysUntilFarrowing ?? 0} days',
            ),
            _PregnancyDetail(
              label: 'Semen used',
              value: pregnancy.semenUsed?.isNotEmpty == true
                  ? pregnancy.semenUsed!
                  : 'Not recorded',
            ),
            const Spacer(),
            Text(
              'Due ${_date(pregnancy.expectedFarrowingDate)} · ${_statusLabel(pregnancy.status)}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PregnancyDetail extends StatelessWidget {
  const _PregnancyDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _statusLabel(String value) => value.replaceAll('_', ' ');
