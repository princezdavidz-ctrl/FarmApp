import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/pregnancy.dart';
import '../providers/pregnancy_provider.dart';

class FarrowingPage extends ConsumerWidget {
  const FarrowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Farrowing')),
      body: pregnancies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error', textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(pregnancyProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          final pending = items
              .where(
                (item) => item.status != 'farrowed' && item.status != 'aborted',
              )
              .toList();

          final body = [
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record farrowing outcome',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pending.isEmpty
                          ? 'No litters are currently pending.'
                          : '${pending.length} sow${pending.length == 1 ? '' : 's'} due for farrowing.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pending litters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No pending farrowing records yet.'),
                ),
              )
            else
              ...pending.map((item) => _FarrowingCard(pregnancy: item)),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: body,
          );
        },
      ),
    );
  }
}

class _FarrowingCard extends StatelessWidget {
  const _FarrowingCard({required this.pregnancy});

  final Pregnancy pregnancy;

  @override
  Widget build(BuildContext context) {
    final dueText = pregnancy.daysUntilFarrowing == null
        ? 'Date pending'
        : '${pregnancy.daysUntilFarrowing} days until farrowing';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pregnancy.sowTag ?? 'Sow ${pregnancy.sowId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due ${_formatDate(pregnancy.expectedFarrowingDate)} • $dueText',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_statusLabel(pregnancy.status)),
                  backgroundColor: Colors.green.shade50,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showOutcomeSheet(context, pregnancy),
                icon: const Icon(Icons.pets_outlined),
                label: const Text('Record outcome'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOutcomeSheet(
    BuildContext context,
    Pregnancy pregnancy,
  ) async {
    final ref = ProviderScope.containerOf(context, listen: false);
    var actualDate = DateTime.now();
    final bornAliveController = TextEditingController(text: '0');
    final stillbornController = TextEditingController(text: '0');
    final mummifiedController = TextEditingController(text: '0');
    final weanedController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farrowing outcome',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Actual farrowing date'),
                  subtitle: Text(_formatDate(actualDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: pregnancy.matingDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: actualDate,
                    );
                    if (picked != null) {
                      setState(() => actualDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bornAliveController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Born alive'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stillbornController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stillborn'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mummifiedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mummified'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weanedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weaned'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      bornAliveController.dispose();
      stillbornController.dispose();
      mummifiedController.dispose();
      weanedController.dispose();
      notesController.dispose();
      return;
    }

    final bornAlive = int.tryParse(bornAliveController.text) ?? 0;
    await ref
        .read(pregnancyProvider.notifier)
        .recordFarrowingOutcome(
          pregnancyId: pregnancy.id,
          actualFarrowingDate: actualDate,
          bornAlive: bornAlive,
          stillborn: int.tryParse(stillbornController.text),
          mummified: int.tryParse(mummifiedController.text),
          weaned: int.tryParse(weanedController.text),
          notes: notesController.text,
        );

    bornAliveController.dispose();
    stillbornController.dispose();
    mummifiedController.dispose();
    weanedController.dispose();
    notesController.dispose();
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _statusLabel(String value) => value.replaceAll('_', ' ');
