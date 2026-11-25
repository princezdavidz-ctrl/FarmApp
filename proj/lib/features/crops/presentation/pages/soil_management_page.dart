import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/crop_plots_provider.dart';
import '../providers/soil_tests_provider.dart';

class SoilManagementPage extends ConsumerStatefulWidget {
  const SoilManagementPage({super.key});

  @override
  ConsumerState<SoilManagementPage> createState() => _SoilManagementPageState();
}

class _SoilManagementPageState extends ConsumerState<SoilManagementPage> {
  String? _plotId;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('Select a farm to manage soil records.')));
    }
    final plots = ref.watch(cropPlotsProvider(farmId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil management'),
        actions: [
          IconButton(
            tooltip: 'Refresh soil records',
            onPressed: () {
              ref.invalidate(cropPlotsProvider(farmId));
              if (_plotId != null) {
                ref.invalidate(soilTestsProvider((farmId: farmId, plotId: _plotId!)));
              }
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: plots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load plots: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a field or plot before recording soil tests.'),
            ));
          }
          final selected = items.any((p) => p['id'].toString() == _plotId)
              ? _plotId
              : items.first['id'].toString();
          if (_plotId != selected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _plotId = selected);
            });
          }
          final key = (farmId: farmId, plotId: selected!);
          final tests = ref.watch(soilTestsProvider(key));
          final plot = items.firstWhere((p) => p['id'].toString() == selected);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DropdownButtonFormField<String>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Farm plot', border: OutlineInputBorder()),
                  items: items.map((p) => DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text(p['name']?.toString() ?? 'Unnamed plot'),
                  )).toList(),
                  onChanged: (value) => setState(() => _plotId = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.science_outlined, size: 30),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plot['name']?.toString() ?? 'Plot', style: Theme.of(context).textTheme.titleMedium),
                            Text('${plot['area_acres'] ?? '—'} acres · ${plot['soil_type'] ?? 'Soil type not specified'}'),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: tests.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Could not load soil history: $error')),
                  data: (records) => records.isEmpty
                      ? const Center(child: Text('No soil tests recorded for this plot yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final test = records[index];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.biotech_outlined)),
                                title: Text('Soil test · ${test['sampled_at'] ?? 'Date unknown'}'),
                                subtitle: Text(_summary(test)),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') _editTest(farmId, selected, test);
                                    if (action == 'delete') _deleteTest(farmId, selected, test);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _plotId == null ? null : () => _editTest(farmId, _plotId!, null),
        icon: const Icon(Icons.add),
        label: const Text('Record soil test'),
      ),
    );
  }

  String _summary(Map<String, dynamic> test) {
    final values = <String>[
      'pH ${test['ph'] ?? '—'}',
      'N ${test['nitrogen_ppm'] ?? '—'} ppm',
      'P ${test['phosphorus_ppm'] ?? '—'} ppm',
      'K ${test['potassium_ppm'] ?? '—'} ppm',
      if (test['organic_matter_percent'] != null) 'Organic matter ${test['organic_matter_percent']}%',
      if (test['moisture_percent'] != null) 'Moisture ${test['moisture_percent']}%',
      if ((test['laboratory_name']?.toString() ?? '').isNotEmpty) 'Lab: ${test['laboratory_name']}',
    ];
    return '${values.join(' · ')}${(test['recommendations']?.toString() ?? '').isEmpty ? '' : '\n${test['recommendations']}'}';
  }

  Future<void> _editTest(String farmId, String plotId, Map<String, dynamic>? test) async {
    final date = TextEditingController(text: test?['sampled_at']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10));
    final lab = TextEditingController(text: test?['laboratory_name']?.toString() ?? '');
    final ph = TextEditingController(text: test?['ph']?.toString() ?? '');
    final n = TextEditingController(text: test?['nitrogen_ppm']?.toString() ?? '');
    final p = TextEditingController(text: test?['phosphorus_ppm']?.toString() ?? '');
    final k = TextEditingController(text: test?['potassium_ppm']?.toString() ?? '');
    final organic = TextEditingController(text: test?['organic_matter_percent']?.toString() ?? '');
    final moisture = TextEditingController(text: test?['moisture_percent']?.toString() ?? '');
    final recommendations = TextEditingController(text: test?['recommendations']?.toString() ?? '');
    final notes = TextEditingController(text: test?['notes']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(test == null ? 'Record soil test' : 'Edit soil test'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: date, decoration: const InputDecoration(labelText: 'Sample date (YYYY-MM-DD)'), validator: (v) => DateTime.tryParse(v ?? '') == null ? 'Enter a valid date' : null),
                TextFormField(controller: lab, decoration: const InputDecoration(labelText: 'Laboratory (optional)')),
                _numberField(ph, 'pH (0–14)', max: 14),
                _numberField(n, 'Nitrogen (ppm)'),
                _numberField(p, 'Phosphorus (ppm)'),
                _numberField(k, 'Potassium (ppm)'),
                _numberField(organic, 'Organic matter (%)', max: 100),
                _numberField(moisture, 'Moisture (%)', max: 100),
                TextFormField(controller: recommendations, maxLines: 3, decoration: const InputDecoration(labelText: 'Lab recommendations')),
                TextFormField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              double? parse(TextEditingController c) => c.text.trim().isEmpty ? null : double.parse(c.text);
              Navigator.pop(dialogContext, {
                'sampled_at': date.text.trim(),
                'laboratory_name': lab.text.trim().isEmpty ? null : lab.text.trim(),
                'ph': parse(ph), 'nitrogen_ppm': parse(n), 'phosphorus_ppm': parse(p),
                'potassium_ppm': parse(k), 'organic_matter_percent': parse(organic),
                'moisture_percent': parse(moisture),
                'recommendations': recommendations.text.trim().isEmpty ? null : recommendations.text.trim(),
                'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
              });
            },
            child: const Text('Save soil test'),
          ),
        ],
      ),
    );
    for (final c in [date, lab, ph, n, p, k, organic, moisture, recommendations, notes]) {
      c.dispose();
    }
    if (payload == null || !mounted) return;
    try {
      final api = ref.read(soilTestsApiProvider);
      if (test == null) {
        await api.create(farmId, plotId, payload);
      } else {
        await api.update(farmId, plotId, test['id'].toString(), payload);
      }
      ref.invalidate(soilTestsProvider((farmId: farmId, plotId: plotId)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save soil test: $error')));
    }
  }

  TextFormField _numberField(TextEditingController controller, String label, {double? max}) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final number = double.tryParse(value);
          if (number == null || number < 0 || (max != null && number > max)) return 'Enter a valid value';
          return null;
        },
      );

  Future<void> _deleteTest(String farmId, String plotId, Map<String, dynamic> test) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete soil test?'),
        content: const Text('This removes the selected soil test from this plot history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(soilTestsApiProvider).delete(farmId, plotId, test['id'].toString());
      ref.invalidate(soilTestsProvider((farmId: farmId, plotId: plotId)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete soil test: $error')));
    }
  }
}
