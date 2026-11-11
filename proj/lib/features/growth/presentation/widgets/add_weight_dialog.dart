import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';

class AddWeightDialog extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const AddWeightDialog({super.key, required this.onSubmit});

  @override
  ConsumerState<AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends ConsumerState<AddWeightDialog> {
  String? _selectedAnimalId;
  late TextEditingController currentWeightController;
  late TextEditingController previousWeightController;
  late TextEditingController targetWeightController;
  late TextEditingController notesController;
  late TextEditingController recordedByController;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    currentWeightController = TextEditingController();
    previousWeightController = TextEditingController();
    targetWeightController = TextEditingController();
    notesController = TextEditingController();
    recordedByController = TextEditingController();
  }

  @override
  void dispose() {
    currentWeightController.dispose();
    previousWeightController.dispose();
    targetWeightController.dispose();
    notesController.dispose();
    recordedByController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final currentWeight = double.tryParse(currentWeightController.text.trim());
    if (_selectedAnimalId == null || currentWeight == null || currentWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an animal and enter a valid weight greater than zero.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    
    final double? previousWeight = double.tryParse(
      previousWeightController.text,
    );
    final double? targetWeight = double.tryParse(targetWeightController.text);

    widget.onSubmit({
      'animal_id': _selectedAnimalId,
      'current_weight': currentWeight,
      'previous_weight': previousWeight,
      'target_weight': targetWeight,
      'measurement_date': _selectedDate.toIso8601String(),
      'recorded_by': recordedByController.text.isNotEmpty
          ? recordedByController.text
          : null,
      'notes': notesController.text.isNotEmpty ? notesController.text : null,
    });
  }

  Widget _buildAnimalSelector() {
    final animals = ref.watch(herdProvider);
    return animals.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Animal list could not be loaded.'),
          TextButton(
            onPressed: () => ref.invalidate(herdProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (items) {
        final eligible = items.where((animal) => animal.status.toLowerCase() == 'active').toList()
          ..sort((a, b) => a.tag.toLowerCase().compareTo(b.tag.toLowerCase()));
        if (_selectedAnimalId != null &&
            !eligible.any((animal) => animal.id == _selectedAnimalId)) {
          _selectedAnimalId = null;
        }
        return DropdownButtonFormField<String>(
          value: _selectedAnimalId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Animal *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
            ),
          ),
          hint: Text(eligible.isEmpty ? 'No active animals found' : 'Select an animal'),
          items: eligible.map((animal) => DropdownMenuItem<String>(
            value: animal.id,
            child: Text(_animalLabel(animal), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: eligible.isEmpty ? null : (value) => setState(() => _selectedAnimalId = value),
        );
      },
    );
  }

  String _animalLabel(Animal animal) {
    final name = animal.name?.trim();
    return name == null || name.isEmpty
        ? '${animal.tag} · ${animal.type} · ${animal.sex}'
        : '${animal.tag} ($name) · ${animal.type}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Weight Measurement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimalSelector(),
            const SizedBox(height: AppDimensions.spacingMedium),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: currentWeightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Current Weight (kg) *',
                hintText: '72.4',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: previousWeightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Previous Weight (kg)',
                hintText: '68.1',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: targetWeightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Target Weight (kg)',
                hintText: '100.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Measurement Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (selectedDate != null) {
                  setState(() => _selectedDate = selectedDate);
                }
              },
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: recordedByController,
              decoration: InputDecoration(
                labelText: 'Recorded By',
                hintText: 'Farm Worker',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Healthy growth...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submitForm, child: const Text('Save')),
      ],
    );
  }
}
