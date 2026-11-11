import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/crop_cycles_provider.dart';

class CropCyclesPage extends ConsumerWidget {
  const CropCyclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('Select a farm to manage crops.')));
    }
    final cycles = ref.watch(cropCyclesProvider(farmId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop farming'),
        actions: [
          IconButton(
            tooltip: 'Refresh crop records',
            onPressed: () => ref.invalidate(cropCyclesProvider(farmId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCropForm(context, ref, farmId),
        icon: const Icon(Icons.add),
        label: const Text('Add crop'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cropCyclesProvider(farmId)),
        child: cycles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              const Center(child: Text('Could not load crop records.')),
              Center(child: TextButton(
                onPressed: () => ref.invalidate(cropCyclesProvider(farmId)),
                child: const Text('Try again'),
              )),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 54),
                    Icon(Icons.agriculture_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 18),
                    Text('Start managing your crops', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Add a field, record what you planted, track crop progress and capture harvest results.',
                      textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    Center(child: FilledButton.icon(
                      onPressed: () => _showCropForm(context, ref, farmId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first crop'),
                    )),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _CropSummary(items: items),
                    const SizedBox(height: 16),
                    for (final item in items)
                      _CropCycleCard(
                        item: item,
                        onStatusChanged: (status) async {
                          await ref.read(cropCyclesApiProvider).update(
                            farmId, item['id'].toString(), {'status': status},
                          );
                          ref.invalidate(cropCyclesProvider(farmId));
                        },
                        onDelete: () async {
                          await ref.read(cropCyclesApiProvider).delete(farmId, item['id'].toString());
                          ref.invalidate(cropCyclesProvider(farmId));
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showCropForm(BuildContext context, WidgetRef ref, String farmId) async {
    final formKey = GlobalKey<FormState>();
    final plot = TextEditingController();
    final crop = TextEditingController();
    final variety = TextEditingController();
    final area = TextEditingController();
    final expectedYield = TextEditingController();
    DateTime plantingDate = DateTime.now();
    DateTime? harvestDate;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add crop cycle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: plot, decoration: const InputDecoration(labelText: 'Field / plot name'), validator: _required),
                    TextFormField(controller: crop, decoration: const InputDecoration(labelText: 'Crop (e.g. maize, beans)'), validator: _required),
                    TextFormField(controller: variety, decoration: const InputDecoration(labelText: 'Variety (optional)')),
                    TextFormField(controller: area, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Area (acres)'), validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) <= 0 ? 'Enter a valid area' : null),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Planting date'),
                      subtitle: Text(_date(plantingDate)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: plantingDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => plantingDate = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expected harvest (optional)'),
                      subtitle: Text(harvestDate == null ? 'Not set' : _date(harvestDate!)),
                      trailing: const Icon(Icons.event_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: harvestDate ?? plantingDate.add(const Duration(days: 90)), firstDate: plantingDate, lastDate: DateTime(2100));
                        if (picked != null) setState(() => harvestDate = picked);
                      },
                    ),
                    TextFormField(controller: expectedYield, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Expected yield (kg, optional)')),
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
                  await ref.read(cropCyclesApiProvider).create(farmId, {
                    'plot_name': plot.text.trim(),
                    'crop_name': crop.text.trim(),
                    'variety': variety.text.trim().isEmpty ? null : variety.text.trim(),
                    'area_acres': double.parse(area.text),
                    'planting_date': _iso(plantingDate),
                    'expected_harvest_date': harvestDate == null ? null : _iso(harvestDate!),
                    'expected_yield_kg': double.tryParse(expectedYield.text),
                    'status': 'planted',
                  });
                  ref.invalidate(cropCyclesProvider(farmId));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not save crop: $error')));
                    setState(() => saving = false);
                  }
                }
              },
              child: Text(saving ? 'Saving…' : 'Save crop'),
            ),
          ],
        ),
      ),
    );
    plot.dispose();
    crop.dispose();
    variety.dispose();
    area.dispose();
    expectedYield.dispose();
  }

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  static String _iso(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _CropSummary extends StatelessWidget {
  const _CropSummary({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !['harvested', 'failed'].contains(item['status'])).length;
    final acres = items.fold<double>(0, (sum, item) => sum + (double.tryParse(item['area_acres']?.toString() ?? '') ?? 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _SummaryValue(label: 'Crop cycles', value: '${items.length}', icon: Icons.grass_outlined)),
            Expanded(child: _SummaryValue(label: 'Active', value: '$active', icon: Icons.eco_outlined)),
            Expanded(child: _SummaryValue(label: 'Acres', value: acres.toStringAsFixed(1), icon: Icons.landscape_outlined)),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 5),
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
    ],
  );
}

class _CropCycleCard extends StatelessWidget {
  const _CropCycleCard({required this.item, required this.onStatusChanged, required this.onDelete});
  final Map<String, dynamic> item;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'planned';
    final color = switch (status) {
      'harvested' => Colors.green,
      'failed' => Theme.of(context).colorScheme.error,
      'growing' => Colors.teal,
      'planted' => Colors.lightGreen.shade800,
      _ => Colors.blueGrey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(Icons.grass, color: color)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['crop_name']?.toString() ?? 'Crop', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(item['plot_name']?.toString() ?? 'Field', style: Theme.of(context).textTheme.bodySmall),
                ])),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete(); else onStatusChanged(value);
                  },
                  itemBuilder: (_) => [
                    for (final value in ['planned', 'planted', 'growing', 'harvested', 'failed'])
                      PopupMenuItem(value: value, child: Text('Set ${value[0].toUpperCase()}${value.substring(1)}')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete crop')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip(label: '${item['area_acres'] ?? '—'} acres'),
              _InfoChip(label: status.replaceFirst(status[0], status[0].toUpperCase())),
              if (item['variety'] != null && item['variety'].toString().isNotEmpty) _InfoChip(label: item['variety'].toString()),
            ]),
            const SizedBox(height: 10),
            Text('Planted: ${item['planting_date'] ?? '—'}', style: Theme.of(context).textTheme.bodySmall),
            if (item['expected_harvest_date'] != null)
              Text('Expected harvest: ${item['expected_harvest_date']}', style: Theme.of(context).textTheme.bodySmall),
            if (item['actual_yield_kg'] != null)
              Text('Harvest recorded: ${item['actual_yield_kg']} kg', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(label),
    padding: EdgeInsets.zero,
  );
}
