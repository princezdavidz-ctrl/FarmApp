import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/crop_plots_provider.dart';

class CropPlotsPage extends ConsumerWidget {
  const CropPlotsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      return const Scaffold(
        body: Center(child: Text('Select a farm to manage fields and plots.')),
      );
    }

    final plots = ref.watch(cropPlotsProvider(farmId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fields & plots'),
        actions: [
          IconButton(
            tooltip: 'Refresh plots',
            onPressed: () => ref.invalidate(cropPlotsProvider(farmId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPlot(context, ref, farmId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add plot'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cropPlotsProvider(farmId)),
        child: plots.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Center(child: Text('Could not load field records.')),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(cropPlotsProvider(farmId)),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 70),
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Set up your farm fields',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create named plots, record their size, soil type and irrigation source. Your records are saved to the selected farm.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => _editPlot(context, ref, farmId),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add your first plot'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _PlotSummary(items: items),
                    const SizedBox(height: 16),
                    for (final plot in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: const Icon(Icons.landscape_outlined),
                          ),
                          title: Text(
                            plot['name']?.toString() ?? 'Unnamed plot',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(_details(plot)),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editPlot(context, ref, farmId, plot: plot);
                              } else if (action == 'delete') {
                                _deletePlot(context, ref, farmId, plot);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _details(Map<String, dynamic> plot) {
    final parts = <String>[
      '${plot['area_acres'] ?? '—'} acres',
      if ((plot['soil_type']?.toString() ?? '').isNotEmpty)
        'Soil: ${plot['soil_type']}',
      if ((plot['irrigation_source']?.toString() ?? '').isNotEmpty)
        'Water: ${plot['irrigation_source']}',
      'Status: ${plot['status'] ?? 'active'}',
    ];
    return parts.join(' · ');
  }

  Future<void> _editPlot(
    BuildContext context,
    WidgetRef ref,
    String farmId, {
    Map<String, dynamic>? plot,
  }) async {
    final name = TextEditingController(text: plot?['name']?.toString() ?? '');
    final area = TextEditingController(text: plot?['area_acres']?.toString() ?? '');
    final soil = TextEditingController(text: plot?['soil_type']?.toString() ?? '');
    final irrigation = TextEditingController(
      text: plot?['irrigation_source']?.toString() ?? '',
    );
    final latitude = TextEditingController(
      text: plot?['latitude']?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: plot?['longitude']?.toString() ?? '',
    );
    final notes = TextEditingController(text: plot?['notes']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    var status = plot?['status']?.toString() ?? 'active';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(plot == null ? 'Add field / plot' : 'Edit field / plot'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Plot name'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a plot name'
                          : null,
                    ),
                    TextFormField(
                      controller: area,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Area (acres)'),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        return parsed == null || parsed <= 0
                            ? 'Enter an area greater than zero'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: soil,
                      decoration: const InputDecoration(labelText: 'Soil type (optional)'),
                    ),
                    TextFormField(
                      controller: irrigation,
                      decoration: const InputDecoration(
                        labelText: 'Irrigation / water source (optional)',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(labelText: 'Latitude'),
                            validator: (value) => _coordinateError(value, -90, 90),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(labelText: 'Longitude'),
                            validator: (value) => _coordinateError(value, -180, 180),
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Plot status'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'fallow', child: Text('Fallow')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (value) => setState(() => status = value ?? 'active'),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'area_acres': double.parse(area.text),
                  'soil_type': _nullable(soil.text),
                  'irrigation_source': _nullable(irrigation.text),
                  'latitude': _numberOrNull(latitude.text),
                  'longitude': _numberOrNull(longitude.text),
                  'status': status,
                  'notes': _nullable(notes.text),
                });
              },
              child: const Text('Save plot'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    area.dispose();
    soil.dispose();
    irrigation.dispose();
    latitude.dispose();
    longitude.dispose();
    notes.dispose();

    if (payload == null) return;
    try {
      final api = ref.read(cropPlotsApiProvider);
      if (plot == null) {
        await api.create(farmId, payload);
      } else {
        await api.update(farmId, plot['id'].toString(), payload);
      }
      ref.invalidate(cropPlotsProvider(farmId));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save plot: $error')),
      );
    }
  }

  Future<void> _deletePlot(
    BuildContext context,
    WidgetRef ref,
    String farmId,
    Map<String, dynamic> plot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete plot?'),
        content: Text('Delete "${plot['name']}" from this farm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(cropPlotsApiProvider).delete(farmId, plot['id'].toString());
      ref.invalidate(cropPlotsProvider(farmId));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete plot: $error')),
      );
    }
  }

  static String? _coordinateError(String? value, double min, double max) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value);
    return parsed == null || parsed < min || parsed > max
        ? 'Enter a value from $min to $max'
        : null;
  }

  static double? _numberOrNull(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value);

  static String? _nullable(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

class _PlotSummary extends StatelessWidget {
  const _PlotSummary({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final totalArea = items.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item['area_acres']?.toString() ?? '') ?? 0),
    );
    final active = items.where((item) => item['status'] == 'active').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _Metric(label: 'Plots', value: '${items.length}')),
            Expanded(child: _Metric(label: 'Active', value: '$active')),
            Expanded(
              child: _Metric(label: 'Total area', value: '${totalArea.toStringAsFixed(2)} ac'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
