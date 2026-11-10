import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/entities/health_record.dart';

class AddHealthRecordDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final String initialType;
  final HealthRecord? initialRecord;

  const AddHealthRecordDialog({
    required this.onSubmit,
    this.initialType = 'treatment',
    this.initialRecord,
    super.key,
  });

  @override
  State<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<AddHealthRecordDialog> {
  late TextEditingController pigIdController;
  late TextEditingController diagnosisController;
  late TextEditingController medicationController;
  late TextEditingController dosageController;
  late TextEditingController veterinarianController;
  late TextEditingController notesController;

  String selectedType = 'treatment';
  String selectedStatus = 'healthy';
  DateTime visitDate = DateTime.now();
  DateTime? nextCheckupDate;
  List<String> symptoms = [];
  bool _saving = false;

  final List<String> types = [
    'vaccination',
    'treatment',
    'deworming',
    'mortality',
  ];
  final List<String> statuses = [
    'healthy',
    'recovering',
    'critical',
    'deceased',
  ];
  final List<String> availableSymptoms = [
    'Fever',
    'Coughing',
    'Lethargy',
    'Loss of appetite',
    'Diarrhea',
    'Vomiting',
    'Lameness',
    'Skin issues',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    selectedType = record?.type ?? widget.initialType;
    selectedStatus = record?.status ?? selectedStatus;
    pigIdController = TextEditingController();
    diagnosisController = TextEditingController();
    medicationController = TextEditingController();
    dosageController = TextEditingController();
    veterinarianController = TextEditingController();
    notesController = TextEditingController();
    pigIdController.text = record?.pigId ?? '';
    diagnosisController.text = record?.diagnosis ?? '';
    medicationController.text = record?.medication ?? '';
    dosageController.text = record?.dosage ?? '';
    veterinarianController.text = record?.veterinarian ?? '';
    notesController.text = record?.notes ?? '';
    visitDate = record?.visitDate ?? visitDate;
    nextCheckupDate = record?.nextCheckupDate;
    symptoms = [...?record?.symptoms];
  }

  @override
  void dispose() {
    pigIdController.dispose();
    diagnosisController.dispose();
    medicationController.dispose();
    dosageController.dispose();
    veterinarianController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRecord() async {
    if (_saving) return;
    if (pigIdController.text.trim().isEmpty) {
      _showError('Please enter a pig ID');
      return;
    }
    setState(() => _saving = true);

    final data = {
      'pig_id': pigIdController.text,
      'type': selectedType,
      'status': selectedStatus,
      'symptoms': symptoms,
      'diagnosis': diagnosisController.text.isNotEmpty
          ? diagnosisController.text
          : null,
      'medication': medicationController.text.isNotEmpty
          ? medicationController.text
          : null,
      'dosage': dosageController.text.isNotEmpty ? dosageController.text : null,
      'veterinarian': veterinarianController.text.isNotEmpty
          ? veterinarianController.text
          : null,
      'visit_date': visitDate.toIso8601String(),
      'next_checkup_date': nextCheckupDate?.toIso8601String(),
      'notes': notesController.text.isNotEmpty ? notesController.text : null,
    };

    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not save the health record. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initialRecord == null
                  ? 'Add Health Record'
                  : 'Edit Health Record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Pig ID (required)
            TextField(
              controller: pigIdController,
              decoration: const InputDecoration(
                labelText: 'Pig ID *',
                hintText: 'e.g., PG-104',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Record Type
            Text('Record Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              onChanged: (value) {
                setState(() => selectedType = value ?? 'treatment');
              },
              items: types
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Status
            Text('Status', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              onChanged: (value) {
                setState(() => selectedStatus = value ?? 'healthy');
              },
              items: statuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Symptoms
            Text('Symptoms', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSymptoms
                  .map(
                    (symptom) => FilterChip(
                      label: Text(symptom),
                      selected: symptoms.contains(symptom),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            symptoms.add(symptom);
                          } else {
                            symptoms.remove(symptom);
                          }
                        });
                      },
                      selectedColor: AppColors.primaryGreen,
                      labelStyle: TextStyle(
                        color: symptoms.contains(symptom)
                            ? AppColors.inverseText
                            : AppColors.text,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Diagnosis
            TextField(
              controller: diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                hintText: 'e.g., Swine influenza',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Medication
            TextField(
              controller: medicationController,
              decoration: const InputDecoration(
                labelText: 'Medication',
                hintText: 'e.g., Oxytetracycline',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Dosage
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g., 5 ml',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Veterinarian
            TextField(
              controller: veterinarianController,
              decoration: const InputDecoration(
                labelText: 'Veterinarian',
                hintText: 'e.g., Dr. Kamau',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Visit Date
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visit Date: ${visitDate.toString().split(' ')[0]}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: visitDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => visitDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Next Checkup Date
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next Checkup: ${nextCheckupDate?.toString().split(' ')[0] ?? 'Not set'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: nextCheckupDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() => nextCheckupDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            // Notes
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                FilledButton(
                  onPressed: _saving ? null : _submitRecord,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.initialRecord == null
                              ? 'Save Record'
                              : 'Save Changes',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
