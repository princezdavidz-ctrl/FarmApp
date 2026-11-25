import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/soil_tests_provider.dart';

class SoilTestsPage extends ConsumerWidget {
  const SoilTestsPage({super.key, required this.farmId, required this.plot});

  final String farmId;
  final Map<String, dynamic> plot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotId = plot['id'].toString();
    final args = (farmId: farmId, plotId: plotId);
    final tests = ref.watch(soilTestsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Text('${plot['name'] ?? 'Plot'} · Soil'),
        actions: [
          IconButton(
            tooltip: 'Refresh soil history',
            onPressed: () => ref.invalidate(soilTestsProvider(args)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, args),
        icon: const Icon(Icons.add),
        label: const Text('Record soil test'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(soilTestsProvider(args)),
        child: tests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              const Center(child: Text('Could not load soil history.')),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(soilTestsProvider(args)),
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
                    const SizedBox(height: 72),
                    Icon(Icons.science_outlined, size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('No soil tests recorded',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Add laboratory or field-test results to build a soil history for this plot.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => _edit(context, ref, args),
                        icon: const Icon(Icons.add),
                        label: const Text('Add first test'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _LatestSummary(test: items.first),
                    const SizedBox(height: 12),
                    for (final item in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.science_outlined),
                          ),
                          title: Text(_date(item['sampled_at']),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(item['laboratory_name']?.toString().isNotEmpty == true
                              ? item['laboratory_name'].toString()
                              : 'Laboratory not specified'),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            _ResultGrid(test: item),
                            if ((item['recommendations']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Lab recommendations',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(item['recommendations'].toString()),
                              ),
                            ],
                            if ((item['notes']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Notes: ${item['notes']}'),
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _edit(context, ref, args, test: item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _delete(context, ref, args, item),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ({String farmId, String plotId}) args, {
    Map<String, dynamic>? test,
  }) async {
    final sampledAt = TextEditingController(text: _date(test?['sampled_at']));
    final lab = TextEditingController(text: test?['laboratory_name']?.toString() ?? '');
    final ph = TextEditingController(text: test?['ph']?.toString() ?? '');
    final nitrogen = TextEditingController(text: test?['nitrogen_ppm']?.toString() ?? '');
    final phosphorus = TextEditingController(text: test?['phosphorus_ppm']?.toString() ?? '');
    final potassium = TextEditingController(text: test?['potassium_ppm']?.toString() ?? '');
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
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: sampledAt,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Sample date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final initial = DateTime.tryParse(sampledAt.text) ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: initial,
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        sampledAt.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                    validator: (value) => DateTime.tryParse(value ?? '') == null
                        ? 'Choose a valid sample date'
                        : null,
                  ),
                  TextFormField(controller: lab, decoration: const InputDecoration(labelText: 'Laboratory (optional)')),
                  const SizedBox(height: 8),
                  _numberField(ph, 'Soil pH', max: 14),
                  _numberField(nitrogen, 'Nitrogen (ppm)'),
                  _numberField(phosphorus, 'Phosphorus (ppm)'),
                  _numberField(potassium, 'Potassium (ppm)'),
                  _numberField(organic, 'Organic matter (%)', max: 100),
                  _numberField(moisture, 'Moisture (%)', max: 100),
                  TextFormField(controller: recommendations, maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Laboratory recommendations')),
                  TextFormField(controller: notes, maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)')),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, {
                'sampled_at': sampledAt.text,
                'laboratory_name': _nullable(lab.text),
                'ph': _number(ph.text),
                'nitrogen_ppm': _number(nitrogen.text),
                'phosphorus_ppm': _number(phosphorus.text),
                'potassium_ppm': _number(potassium.text),
                'organic_matter_percent': _number(organic.text),
                'moisture_percent': _number(moisture.text),
                'recommendations': _nullable(recommendations.text),
                'notes': _nullable(notes.text),
              });
            },
            child: const Text('Save results'),
          ),
        ],
      ),
    );

    for (final controller in [sampledAt, lab, ph, nitrogen, phosphorus, potassium, organic, moisture, recommendations, notes]) {
      controller.dispose();
    }
    if (payload == null) return;

    try {
      final api = ref.read(soilTestsApiProvider);
      if (test == null) {
        await api.create(args.farmId, args.plotId, payload);
      } else {
        await api.update(args.farmId, args.plotId, test['id'].toString(), payload);
      }
      ref.invalidate(soilTestsProvider(args));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save soil test: $error')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ({String farmId, String plotId}) args,
    Map<String, dynamic> test,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete soil test?'),
        content: const Text('This removes this test record from the plot history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(soilTestsApiProvider).delete(args.farmId, args.plotId, test['id'].toString());
      ref.invalidate(soilTestsProvider(args));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete soil test: $error')),
      );
    }
  }
}

Widget _numberField(TextEditingController controller, String label, {double? max}) {
  return TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = double.tryParse(value);
      if (parsed == null || parsed < 0 || (max != null && parsed > max)) {
        return max == null ? 'Enter a valid non-negative number' : 'Enter a value from 0 to $max';
      }
      return null;
    },
  );
}

class _LatestSummary extends StatelessWidget {
  const _LatestSummary({required this.test});
  final Map<String, dynamic> test;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Latest soil test', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ResultGrid(test: test),
            ],
          ),
        ),
      );
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.test});
  final Map<String, dynamic> test;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('pH', test['ph']),
      ('Nitrogen', _withUnit(test['nitrogen_ppm'], 'ppm')),
      ('Phosphorus', _withUnit(test['phosphorus_ppm'], 'ppm')),
      ('Potassium', _withUnit(test['potassium_ppm'], 'ppm')),
      ('Organic matter', _withUnit(test['organic_matter_percent'], '%')),
      ('Moisture', _withUnit(test['moisture_percent'], '%')),
    ];
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: [
        for (final entry in values)
          SizedBox(
            width: 125,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.$1, style: Theme.of(context).textTheme.bodySmall),
                Text(entry.$2?.toString() ?? 'Not recorded',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

String? _withUnit(dynamic value, String unit) =>
    value == null ? null : '$value $unit';

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

double? _number(String value) => value.trim().isEmpty ? null : double.tryParse(value);
String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
