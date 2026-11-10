import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';
import '../../domain/entities/health_record.dart';

class AddHealthRecordPage extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final String initialType;
  final HealthRecord? initialRecord;

  const AddHealthRecordPage({
    required this.onSubmit,
    this.initialType = 'treatment',
    this.initialRecord,
    super.key,
  });

  @override
  ConsumerState<AddHealthRecordPage> createState() =>
      _AddHealthRecordPageState();
}

class _AddHealthRecordPageState extends ConsumerState<AddHealthRecordPage> {
  late TextEditingController diagnosisController;
  late TextEditingController medicationController;
  late TextEditingController dosageController;
  late TextEditingController veterinarianController;
  late TextEditingController notesController;

  String? _selectedAnimalId;
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
    diagnosisController = TextEditingController();
    medicationController = TextEditingController();
    dosageController = TextEditingController();
    veterinarianController = TextEditingController();
    notesController = TextEditingController();
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
    diagnosisController.dispose();
    medicationController.dispose();
    dosageController.dispose();
    veterinarianController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRecord() async {
    if (_saving) return;
    final animal = _selectedAnimal;
    if (animal == null) {
      _showError('Select a pig from this farm’s herd before saving.');
      return;
    }
    setState(() => _saving = true);

    final data = {
      'animal_id': animal.id,
      'type': selectedType,
      'status': selectedStatus,
      'symptoms': symptoms,
      'diagnosis': diagnosisController.text.trim().isNotEmpty
          ? diagnosisController.text.trim()
          : null,
      'medication': medicationController.text.trim().isNotEmpty
          ? medicationController.text.trim()
          : null,
      'dosage': dosageController.text.trim().isNotEmpty
          ? dosageController.text.trim()
          : null,
      'veterinarian': veterinarianController.text.trim().isNotEmpty
          ? veterinarianController.text.trim()
          : null,
      'visit_date': DateUtils.dateOnly(visitDate).toIso8601String(),
      'next_checkup_date': nextCheckupDate?.toIso8601String(),
      'notes': notesController.text.trim().isNotEmpty
          ? notesController.text.trim()
          : null,
    };

    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError('Could not save the health record: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Animal? get _selectedAnimal {
    final animals = ref.read(herdProvider).valueOrNull ?? const <Animal>[];
    final selectedId = _selectedAnimalId;
    if (selectedId != null) {
      for (final animal in animals) {
        if (animal.id == selectedId) return animal;
      }
    }

    final initialTag = widget.initialRecord?.pigId;
    if (initialTag != null) {
      for (final animal in animals) {
        if (animal.tag == initialTag) return animal;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final herdState = ref.watch(herdProvider);
    final animals = herdState.valueOrNull ?? const <Animal>[];
    var initialAnimalId = _selectedAnimalId;
    if (initialAnimalId == null && widget.initialRecord != null) {
      for (final animal in animals) {
        if (animal.tag == widget.initialRecord!.pigId) {
          initialAnimalId = animal.id;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialRecord == null
              ? 'Add Health Record'
              : 'Edit Health Record',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pig', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  DropdownButtonFormField<String>(
                    initialValue: initialAnimalId,
                    decoration: const InputDecoration(
                      labelText: 'Select pig',
                      prefixIcon: Icon(Icons.pets_outlined),
                    ),
                    items: animals
                        .map(
                          (animal) => DropdownMenuItem(
                            value: animal.id,
                            child: Text(
                              animal.name?.isNotEmpty == true
                                  ? '${animal.name} · ${animal.tag}'
                                  : '${animal.tag} · ${animal.type}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAnimalId = value),
                  ),
                  if (herdState.isLoading) ...[
                    const SizedBox(height: AppDimensions.spacingSmall),
                    const LinearProgressIndicator(),
                  ] else if (herdState.hasError) ...[
                    const SizedBox(height: AppDimensions.spacingSmall),
                    Text(
                      'Could not load this farm’s herd: ${herdState.error}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(herdProvider),
                      child: const Text('Retry'),
                    ),
                  ] else if (animals.isEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingSmall),
                    Text(
                      'No pigs are available in this farm’s herd. Add a pig to the herd before recording health details.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingMedium),
                  // Record Type
                  Text(
                    'Record Type',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    onChanged: (value) {
                      setState(() => selectedType = value ?? 'treatment');
                    },
                    items: types
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  // Symptoms
                  Text(
                    'Symptoms',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || initialAnimalId == null
                          ? null
                          : _submitRecord,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        widget.initialRecord == null
                            ? 'Save Record'
                            : 'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
