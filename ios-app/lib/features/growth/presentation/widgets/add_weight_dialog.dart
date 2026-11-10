import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';

class AddWeightDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const AddWeightDialog({super.key, required this.onSubmit});

  @override
  State<AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends State<AddWeightDialog> {
  late TextEditingController pigIdController;
  late TextEditingController currentWeightController;
  late TextEditingController previousWeightController;
  late TextEditingController targetWeightController;
  late TextEditingController notesController;
  late TextEditingController recordedByController;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    pigIdController = TextEditingController();
    currentWeightController = TextEditingController();
    previousWeightController = TextEditingController();
    targetWeightController = TextEditingController();
    notesController = TextEditingController();
    recordedByController = TextEditingController();
  }

  @override
  void dispose() {
    pigIdController.dispose();
    currentWeightController.dispose();
    previousWeightController.dispose();
    targetWeightController.dispose();
    notesController.dispose();
    recordedByController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (pigIdController.text.isEmpty || currentWeightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Pig ID and Current Weight'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final double currentWeight =
        double.tryParse(currentWeightController.text) ?? 0;
    final double? previousWeight = double.tryParse(
      previousWeightController.text,
    );
    final double? targetWeight = double.tryParse(targetWeightController.text);

    widget.onSubmit({
      'animal_id': pigIdController.text,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Weight Measurement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pigIdController,
              decoration: InputDecoration(
                labelText: 'Pig ID *',
                hintText: 'e.g., PG-104',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
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
