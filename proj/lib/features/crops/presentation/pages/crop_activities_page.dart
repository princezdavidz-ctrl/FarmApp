import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/crop_activities_provider.dart';
import '../providers/crop_cycles_provider.dart';

class CropActivitiesPage extends ConsumerWidget {
  const CropActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('Select a farm to manage crop activities.')));
    }

    final activities = ref.watch(cropActivitiesProvider(farmId));
    final cycles = ref.watch(cropCyclesProvider(farmId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field activities'),
        actions: [
          IconButton(
            tooltip: 'Refresh activities',
            onPressed: () => ref.invalidate(cropActivitiesProvider(farmId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showActivityForm(context, ref, farmId, cycles.valueOrNull ?? const []),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record activity'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cropActivitiesProvider(farmId));
          ref.invalidate(cropCyclesProvider(farmId));
        },
        child: activities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Center(child: Text('Could not load field activities.')),
              Center(child: TextButton(
                onPressed: () => ref.invalidate(cropActivitiesProvider(farmId)),
                child: const Text('Try again'),
              )),
            ],
          ),
          data: (items) {
            final sorted = [...items]..sort((a, b) {
              final aDate = DateTime.tryParse(a['activity_date']?.toString() ?? '') ?? DateTime(1970);
              final bDate = DateTime.tryParse(b['activity_date']?.toString() ?? '') ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });
            final totalCost = sorted.fold<double>(
              0,
              (sum, item) => sum + (double.tryParse(item['cost']?.toString() ?? '') ?? 0),
            );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _ActivitySummary(count: sorted.length, cost: totalCost),
                const SizedBox(height: 20),
                Text('Activity history', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (sorted.isEmpty)
                  const _EmptyActivities()
                else
                  for (final item in sorted)
                    _ActivityCard(
                      item: item,
                      onDelete: () async {
                        await ref.read(cropActivitiesApiProvider).delete(farmId, item['id'].toString());
                        ref.invalidate(cropActivitiesProvider(farmId));
                      },
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showActivityForm(
    BuildContext context,
    WidgetRef ref,
    String farmId,
    List<Map<String, dynamic>> cycles,
  ) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final product = TextEditingController();
    final quantity = TextEditingController();
    final unit = TextEditingController();
    final cost = TextEditingController();
    final notes = TextEditingController();
    var type = 'irrigation';
    String? cycleId;
    var date = DateTime.now();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record field activity'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Activity type'),
                      items: const [
                        DropdownMenuItem(value: 'irrigation', child: Text('Irrigation')),
                        DropdownMenuItem(value: 'fertilizer', child: Text('Fertilizer application')),
                        DropdownMenuItem(value: 'pesticide', child: Text('Pest control')),
                        DropdownMenuItem(value: 'herbicide', child: Text('Weed control')),
                        DropdownMenuItem(value: 'weeding', child: Text('Weeding')),
                        DropdownMenuItem(value: 'pruning', child: Text('Pruning')),
                        DropdownMenuItem(value: 'scouting', child: Text('Field inspection')),
                        DropdownMenuItem(value: 'planting', child: Text('Planting')),
                        DropdownMenuItem(value: 'harvest', child: Text('Harvest')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => type = value ?? 'other'),
                    ),
                    if (cycles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: cycleId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Crop cycle (optional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('General field activity')),
                          for (final cycle in cycles)
                            DropdownMenuItem(
                              value: cycle['id'].toString(),
                              child: Text('${cycle['crop_name'] ?? 'Crop'} · ${cycle['plot_name'] ?? 'Field'}', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (value) => setState(() => cycleId = value),
                      ),
                    ],
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Activity description'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    TextFormField(controller: product, decoration: const InputDecoration(labelText: 'Product / input (optional)')),
                    Row(
                      children: [
                        Expanded(child: TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantity'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return null;
                            final parsed = double.tryParse(value);
                            return parsed == null || parsed <= 0 ? 'Enter a positive amount' : null;
                          },
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (kg, L, bags)'))),
                      ],
                    ),
                    TextFormField(
                      controller: cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cost (KES, optional)'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final parsed = double.tryParse(value);
                        return parsed == null || parsed < 0 ? 'Enter a valid cost' : null;
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activity date'),
                      subtitle: Text(_formatDate(date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setState(() => saving = true);
                try {
                  await ref.read(cropActivitiesApiProvider).create(farmId, {
                    'crop_cycle_id': cycleId,
                    'activity_type': type,
                    'activity_date': _isoDate(date),
                    'title': title.text.trim(),
                    'product_name': product.text.trim().isEmpty ? null : product.text.trim(),
                    'quantity': double.tryParse(quantity.text),
                    'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
                    'cost': double.tryParse(cost.text),
                    'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  });
                  ref.invalidate(cropActivitiesProvider(farmId));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not save activity: $error')));
                    setState(() => saving = false);
                  }
                }
              },
              child: Text(saving ? 'Saving…' : 'Save activity'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    product.dispose();
    quantity.dispose();
    unit.dispose();
    cost.dispose();
    notes.dispose();
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.count, required this.cost});
  final int count;
  final double cost;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _Metric(icon: Icons.event_note_outlined, label: 'Activities', value: '$count')),
          Expanded(child: _Metric(icon: Icons.payments_outlined, label: 'Recorded costs', value: 'KES ${cost.toStringAsFixed(0)}')),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = item['activity_type']?.toString() ?? 'other';
    final label = type.replaceAll('_', ' ').split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
    final quantity = item['quantity']?.toString();
    final unit = item['unit']?.toString();
    final date = DateTime.tryParse(item['activity_date']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_activityIcon(type))),
        title: Text(item['title']?.toString() ?? label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date == null ? 'Date not set' : _formatDate(date)} · $label'),
            if (item['product_name'] != null) Text(item['product_name'].toString()),
            if (quantity != null) Text('Quantity: $quantity ${unit ?? ''}'),
            if (item['cost'] != null) Text('Cost: KES ${item['cost']}'),
            if (item['notes'] != null) Text(item['notes'].toString()),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Delete activity',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete activity?'),
                content: const Text('This removes the selected field activity record.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed == true) onDelete();
          },
        ),
      ),
    );
  }
}

class _EmptyActivities extends StatelessWidget {
  const _EmptyActivities();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.agriculture_outlined, size: 46),
          const SizedBox(height: 12),
          Text('No field activities yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Record irrigation, fertilizer, pest control, weeding and harvest work as it happens.', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

IconData _activityIcon(String type) => switch (type) {
  'irrigation' => Icons.water_drop_outlined,
  'fertilizer' => Icons.grass_outlined,
  'pesticide' || 'herbicide' => Icons.sanitizer_outlined,
  'harvest' => Icons.agriculture_outlined,
  'planting' => Icons.spa_outlined,
  'weeding' || 'pruning' => Icons.content_cut_outlined,
  'scouting' => Icons.search_outlined,
  _ => Icons.event_note_outlined,
};

String _isoDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
