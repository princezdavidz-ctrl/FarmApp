import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/feed_formulations_provider.dart';

class FormulationPage extends ConsumerWidget {
  const FormulationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formulations = ref.watch(feedFormulationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Feed formulations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New formulation'),
      ),
      body: formulations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(error: error, onRetry: () => ref.invalidate(feedFormulationsProvider)),
        data: (items) => items.isEmpty
            ? _EmptyState(onCreate: () => _openEditor(context, ref))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(feedFormulationsProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _IntroCard(count: items.length),
                    const SizedBox(height: 16),
                    for (final item in items)
                      _FormulationCard(item: item, onDelete: () => _confirmDelete(context, ref, item)),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true, builder: (_) => const _FormulationEditor(),
    );
    if (created == true) ref.invalidate(feedFormulationsProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete formulation?'),
        content: Text('“${item['name']}” will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(feedFormulationsProvider.notifier).delete('${item['id']}');
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete formulation: $error')));
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.deepGreen,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.science_outlined, color: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Plan balanced feed batches', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$count saved formulation${count == 1 ? '' : 's'} · Ingredient ratios, nutrition estimates and cost', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ])),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.science_outlined, size: 58, color: AppColors.mutedText),
        const SizedBox(height: 16),
        Text('No formulations yet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Create a recipe, set ingredient inclusion rates and estimate the nutrients and cost of a batch.', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create formulation')),
      ]),
    ),
  );
}

class _FormulationCard extends StatelessWidget {
  const _FormulationCard({required this.item, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  String _number(Object? value, {int digits = 2}) => value is num ? value.toStringAsFixed(digits) : '—';

  @override
  Widget build(BuildContext context) {
    final ingredients = (item['ingredients'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
    final protein = item['estimated_crude_protein_percent'];
    final energy = item['estimated_energy_mj_per_kg'];
    final cost = item['estimated_cost_per_kg'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item['name']?.toString() ?? 'Feed formulation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            PopupMenuButton<String>(onSelected: (value) { if (value == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))]),
          ]),
          Text('${_speciesLabel(item['target_species'])} · ${_number(item['batch_size_kg'])} kg batch', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _EstimateChip(label: 'Crude protein', value: protein == null ? 'Not entered' : '${_number(protein)}%'),
            _EstimateChip(label: 'Energy', value: energy == null ? 'Not entered' : '${_number(energy)} MJ/kg'),
            _EstimateChip(label: 'Cost/kg', value: cost == null ? 'Not entered' : 'KES ${_number(cost)}'),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          for (final ingredient in ingredients)
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
              Expanded(child: Text(ingredient['name']?.toString() ?? 'Ingredient')),
              Text('${_number(ingredient['inclusion_percent'], digits: 1)}%'),
              const SizedBox(width: 12),
              Text('${_number(ingredient['batch_quantity_kg'])} kg'),
            ])),
          if ((item['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item['notes'].toString(), style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }

  static String _speciesLabel(Object? value) => switch (value) {
    'pigs' => 'Pigs', 'cattle' => 'Cattle', 'poultry' => 'Poultry',
    'goats' => 'Goats', 'sheep' => 'Sheep', 'rabbits' => 'Rabbits', _ => 'Other',
  };
}

class _EstimateChip extends StatelessWidget {
  const _EstimateChip({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ]),
  );
}

class _FormulationEditor extends ConsumerStatefulWidget {
  const _FormulationEditor();
  @override
  ConsumerState<_FormulationEditor> createState() => _FormulationEditorState();
}

class _FormulationEditorState extends ConsumerState<_FormulationEditor> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _batch = TextEditingController(text: '100');
  final _notes = TextEditingController();
  final List<_IngredientDraft> _ingredients = [_IngredientDraft(), _IngredientDraft()];
  String _species = 'pigs';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _batch.dispose(); _notes.dispose();
    for (final ingredient in _ingredients) { ingredient.dispose(); }
    super.dispose();
  }

  double get _percentageTotal => _ingredients.fold(0, (sum, item) => sum + (double.tryParse(item.inclusion.text) ?? 0));
  double get _estimatedCost {
    var total = 0.0;
    for (final item in _ingredients) {
      final percent = double.tryParse(item.inclusion.text) ?? 0;
      final cost = double.tryParse(item.cost.text);
      if (cost == null) return double.nan;
      total += percent * cost / 100;
    }
    return total;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_percentageTotal - 100).abs() > .01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ingredient percentages must total 100% (currently ${_percentageTotal.toStringAsFixed(1)}%).')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(feedFormulationsProvider.notifier).create({
        'name': _name.text.trim(), 'target_species': _species,
        'batch_size_kg': double.parse(_batch.text),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'ingredients': _ingredients.map((item) => {
          'name': item.name.text.trim(),
          'inclusion_percent': double.parse(item.inclusion.text),
          if (item.protein.text.trim().isNotEmpty) 'crude_protein_percent': double.parse(item.protein.text),
          if (item.energy.text.trim().isNotEmpty) 'energy_mj_per_kg': double.parse(item.energy.text),
          if (item.cost.text.trim().isNotEmpty) 'cost_per_kg': double.parse(item.cost.text),
        }).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save formulation: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchSize = double.tryParse(_batch.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create formulation', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Formulation name'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a name' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _species, decoration: const InputDecoration(labelText: 'Target animal'),
            items: const [
              DropdownMenuItem(value: 'pigs', child: Text('Pigs')), DropdownMenuItem(value: 'cattle', child: Text('Cattle')),
              DropdownMenuItem(value: 'poultry', child: Text('Poultry')), DropdownMenuItem(value: 'goats', child: Text('Goats')),
              DropdownMenuItem(value: 'sheep', child: Text('Sheep')), DropdownMenuItem(value: 'rabbits', child: Text('Rabbits')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _species = value ?? _species),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _batch, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Batch size (kg)'),
            validator: (value) { final number = double.tryParse(value ?? ''); return number == null || number <= 0 ? 'Enter a positive batch size' : null; },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text('Ingredients', style: Theme.of(context).textTheme.titleMedium)),
            Text('${_percentageTotal.toStringAsFixed(1)}% / 100%', style: TextStyle(color: (_percentageTotal - 100).abs() < .01 ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('Enter values from your ingredient supplier or feed label. Nutrition and cost estimates are calculated from these inputs.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
          const SizedBox(height: 12),
          for (var index = 0; index < _ingredients.length; index++)
            _IngredientEditor(
              key: ObjectKey(_ingredients[index]), index: index, draft: _ingredients[index],
              batchSize: batchSize, canRemove: _ingredients.length > 2,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() { final removed = _ingredients.removeAt(index); removed.dispose(); }),
            ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: _ingredients.length >= 30 ? null : () => setState(() => _ingredients.add(_IngredientDraft())),
            icon: const Icon(Icons.add), label: const Text('Add ingredient'),
          )),
          if (!_estimatedCost.isNaN) ...[
            const SizedBox(height: 8),
            Text('Estimated ingredient cost: KES ${_estimatedCost.toStringAsFixed(2)} / kg · KES ${(_estimatedCost * batchSize).toStringAsFixed(2)} per batch', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save formulation'),
          )),
        ])),
      ),
    );
  }
}

class _IngredientDraft {
  final name = TextEditingController();
  final inclusion = TextEditingController();
  final protein = TextEditingController();
  final energy = TextEditingController();
  final cost = TextEditingController();
  void dispose() { name.dispose(); inclusion.dispose(); protein.dispose(); energy.dispose(); cost.dispose(); }
}

class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({super.key, required this.index, required this.draft, required this.batchSize, required this.canRemove, required this.onChanged, required this.onRemove});
  final int index;
  final _IngredientDraft draft;
  final double batchSize;
  final bool canRemove;
  final VoidCallback onChanged, onRemove;

  String? _positive(String? value) { final number = double.tryParse(value ?? ''); return number == null || number <= 0 ? 'Required' : null; }
  String? _optionalPercent(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value);
    return number == null || number < 0 || number > 100 ? '0–100' : null;
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('Ingredient ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
          if (canRemove) IconButton(tooltip: 'Remove ingredient', onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
        ]),
        TextFormField(controller: draft.name, decoration: const InputDecoration(labelText: 'Ingredient name'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null, onChanged: (_) => onChanged()),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(controller: draft.inclusion, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Inclusion %'), validator: _positive, onChanged: (_) => onChanged())),
          const SizedBox(width: 10),
          Expanded(child: Builder(builder: (context) {
            final quantity = (double.tryParse(draft.inclusion.text) ?? 0) * batchSize / 100;
            return InputDecorator(decoration: const InputDecoration(labelText: 'Batch quantity'), child: Text('${quantity.toStringAsFixed(2)} kg'));
          })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(controller: draft.protein, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Crude protein %'), validator: _optionalPercent, onChanged: (_) => onChanged())),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: draft.energy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Energy MJ/kg'), validator: _optionalPercent, onChanged: (_) => onChanged())),
        ]),
        const SizedBox(height: 8),
        TextFormField(controller: draft.cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost per kg (KES, optional)'), validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final number = double.tryParse(value);
          return number == null || number < 0 ? 'Enter 0 or more' : null;
        }, onChanged: (_) => onChanged()),
      ]),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined, size: 42),
      const SizedBox(height: 12),
      const Text('Could not load feed formulations.'),
      const SizedBox(height: 6),
      Text('$error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
    ]),
  ));
}
