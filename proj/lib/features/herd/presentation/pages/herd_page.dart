import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../breeding/presentation/providers/pregnancy_provider.dart';
import '../../domain/entities/animal.dart';
import '../providers/herd_provider.dart';

class HerdPage extends ConsumerWidget {
  const HerdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final herd = ref.watch(herdProvider);
    final registeredFarm = ref.watch(authProvider).valueOrNull?.selectedFarm;
    final registeredHerdCount = registeredFarm?.registeredHerdCount ?? 0;
    final currentAnimals = herd.valueOrNull ?? const <Animal>[];
    final remainingRegistrationCount =
        (registeredHerdCount - currentAnimals.length).clamp(
          0,
          registeredHerdCount,
        );
    final canAutoFillHerd = herd.hasValue && remainingRegistrationCount > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.herdPageTitle),
        leading: IconButton(
          tooltip: l10n.openMenu,
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.refreshHerd,
            onPressed: () => ref.invalidate(herdProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canAutoFillHerd) ...[
            FloatingActionButton.extended(
              heroTag: 'autofill-herd',
              onPressed: () => _autoFillRegisteredPigs(
                context,
                ref,
                animals: currentAnimals,
                registeredHerdCount: registeredHerdCount,
                motherPigCount: registeredFarm?.motherPigCount ?? 0,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Auto-fill herd'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'add-herd-pig',
            onPressed: () => _showAnimalDetailsPage(
              context,
              ref,
              initialTag: _nextPigTag(currentAnimals),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.addPig),
          ),
        ],
      ),
      body: herd.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(herdProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Could not load herd: $error'),
          ),
        ),
        data: (animals) {
          var searchQuery = '';
          var statusFilter = 'all';
          return StatefulBuilder(
            builder: (context, setLocalState) {
              final filteredAnimals = animals.where((animal) {
                final matchesSearch =
                    '${animal.tag} ${animal.type} ${animal.sex} ${animal.notes ?? ''}'
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
                return matchesSearch &&
                    (statusFilter == 'all' || animal.status == statusFilter);
              }).toList();
              final displayedHerdCount = animals.length > registeredHerdCount
                  ? animals.length
                  : registeredHerdCount;
              final reservedTags = animals
                  .map((animal) => animal.tag.toUpperCase())
                  .toSet();
              final remainingMothers =
                  ((registeredFarm?.motherPigCount ?? 0) -
                          animals
                              .where((animal) => animal.type == 'sow')
                              .length)
                      .clamp(0, registeredHerdCount)
                      .toInt();
              final remainingPiglets =
                  ((registeredFarm?.registeredPigletCount ?? 0) -
                          animals
                              .where((animal) => animal.type == 'piglet')
                              .length)
                      .clamp(0, registeredHerdCount)
                      .toInt();
              final registrationSlots = <_RegistrationSlot>[
                for (var index = 0; index < remainingMothers; index++)
                  _RegistrationSlot(
                    type: 'sow',
                    number: index + 1,
                    suggestedTag: _nextPigTag(animals, reservedTags),
                  ),
                for (var index = 0; index < remainingPiglets; index++)
                  _RegistrationSlot(
                    type: 'piglet',
                    number: index + 1,
                    suggestedTag: _nextPigTag(animals, reservedTags),
                  ),
              ];
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(herdProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.pagePadding,
                    AppDimensions.pagePadding,
                    AppDimensions.pagePadding,
                    96,
                  ),
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setLocalState(() => searchQuery = value),
                      decoration: InputDecoration(
                        hintText: l10n.searchAnimals,
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['all', 'active', 'sold', 'deceased']
                            .map(
                              (status) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(switch (status) {
                                    'all' => l10n.allPigs,
                                    'active' => l10n.active,
                                    'sold' => l10n.sold,
                                    _ => l10n.deceased,
                                  }),
                                  selected: statusFilter == status,
                                  onSelected: (_) => setLocalState(
                                    () => statusFilter = status,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    _HerdSummary(
                      label: l10n.registeredHerd,
                      value: '$displayedHerdCount',
                      icon: Icons.pets_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (registrationSlots.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingMedium),
                      _RegistrationSlotsGrid(
                        slots: registrationSlots,
                        onAdd: (slot) => _showAnimalDetailsPage(
                          context,
                          ref,
                          initialType: slot.type,
                          initialTag: slot.suggestedTag,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingLarge),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.yourAnimals,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${filteredAnimals.length} ${l10n.shown}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (filteredAnimals.isEmpty)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.pets_outlined,
                                size: 40,
                                color: AppColors.primaryGreen,
                              ),
                              SizedBox(height: 12),
                              Text(
                                searchQuery.isEmpty
                                    ? l10n.noPigsFound
                                    : l10n.noMatchingPigs,
                              ),
                              SizedBox(height: 4),
                              Text(
                                l10n.adjustSearchOrFilters,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 700
                              ? 3
                              : constraints.maxWidth >= 380
                              ? 2
                              : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredAnimals.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: AppDimensions.spacingMedium,
                                  mainAxisSpacing: AppDimensions.spacingMedium,
                                  childAspectRatio: columns == 1 ? 1.6 : 0.65,
                                ),
                            itemBuilder: (context, index) {
                              final animal = filteredAnimals[index];
                              return _AnimalCard(
                                animal: animal,
                                onEdit: () =>
                                    _showEditAnimalDialog(context, ref, animal),
                                onArchive: () =>
                                    _archiveAnimal(context, ref, animal),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAnimalDetailsPage(
    BuildContext context,
    WidgetRef ref, {
    String initialType = 'sow',
    required String initialTag,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _EditAnimalPage(initialType: initialType, initialTag: initialTag),
      ),
    );
  }

  Future<void> _archiveAnimal(
    BuildContext context,
    WidgetRef ref,
    Animal animal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive animal?'),
        content: Text(
          'Mark ${animal.tag} as deceased and remove it from active herd tracking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(herdProvider.notifier).archiveAnimal(animal.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not archive animal: $error')),
        );
      }
    }
  }

  Future<void> _showEditAnimalDialog(
    BuildContext context,
    WidgetRef ref,
    Animal animal,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditAnimalPage(animal: animal),
      ),
    );
  }
}

class _EditAnimalPage extends ConsumerStatefulWidget {
  const _EditAnimalPage({
    this.animal,
    this.initialType = 'sow',
    this.initialTag,
  });

  final Animal? animal;
  final String initialType;
  final String? initialTag;

  @override
  ConsumerState<_EditAnimalPage> createState() => _EditAnimalPageState();
}

class _EditAnimalPageState extends ConsumerState<_EditAnimalPage> {
  static const _maximumImageBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagController;
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  late String _sex;
  late String _status;
  late bool _isPregnant;
  late DateTime? _birthDate;
  late DateTime? _lastDewormedAt;
  late DateTime? _lastVaccinatedAt;
  Uint8List? _imageBytes;
  String? _imageName;
  late String _type;
  bool _saving = false;

  Animal? get animal => widget.animal;
  bool get isCreating => animal == null;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController(
      text: animal?.tag ?? widget.initialTag ?? '',
    );
    _nameController = TextEditingController(text: animal?.name ?? '');
    _weightController = TextEditingController(
      text: animal?.weightKg?.toString() ?? '',
    );
    _notesController = TextEditingController(text: animal?.notes ?? '');
    _type = animal?.type ?? widget.initialType;
    _sex =
        animal?.sex ??
        switch (_type) {
          'boar' => 'male',
          'sow' => 'female',
          _ => 'unknown',
        };
    _status = animal?.status ?? 'active';
    _isPregnant = animal?.isPregnant ?? false;
    _birthDate = animal?.birthDate;
    _lastDewormedAt = animal?.lastDewormedAt;
    _lastVaccinatedAt = animal?.lastVaccinatedAt;
  }

  @override
  void dispose() {
    _tagController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maximumImageBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pig photos must be 5 MB or smaller.')),
        );
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load pig photo: $error')),
        );
      }
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: now,
      initialDate: current ?? now,
    );
    if (picked != null && mounted) onSelected(picked);
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (isCreating) {
        await ref
            .read(herdProvider.notifier)
            .createAnimal(
              tag: _tagController.text.trim(),
              type: _type,
              sex: _sex,
              status: _status,
              name: _nameController.text.trim(),
              birthDate: _birthDate,
              weightKg: double.tryParse(_weightController.text.trim()),
              isPregnant: _sex == 'female' && _isPregnant,
              lastDewormedAt: _lastDewormedAt,
              lastVaccinatedAt: _lastVaccinatedAt,
              notes: _notesController.text,
              imageBytes: _imageBytes,
              imageName: _imageName,
            );
      } else {
        await ref
            .read(herdProvider.notifier)
            .updateAnimal(
              animalId: animal!.id,
              name: _nameController.text.trim(),
              sex: _sex,
              status: _status,
              birthDate: _birthDate,
              weightKg: double.tryParse(_weightController.text.trim()),
              isPregnant: _sex == 'female' && _isPregnant,
              lastDewormedAt: _lastDewormedAt,
              lastVaccinatedAt: _lastVaccinatedAt,
              notes: _notesController.text,
              imageBytes: _imageBytes,
              imageName: _imageName,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        final action = isCreating ? 'add pig' : 'update ${animal!.tag}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not $action: $error')));
      }
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Not recorded';
    return '${value.day}/${value.month}/${value.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isCreating ? 'Add pig details' : 'Edit ${animal!.tag}'),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 220,
                height: 180,
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                    : animal?.imageUrl == null
                    ? const ColoredBox(
                        color: AppColors.pigPink,
                        child: Icon(Icons.pets_outlined, size: 64),
                      )
                    : Image.network(
                        animal!.imageUrl!,
                        key: ValueKey(animal!.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.pigPink,
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _imageBytes == null
                    ? (isCreating ? 'Add photo' : 'Change photo')
                    : 'Photo selected',
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (isCreating)
            TextFormField(
              controller: _tagController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Pig tag'),
              validator: (value) {
                final tag = value?.trim() ?? '';
                if (tag.isEmpty) return 'Enter an animal tag.';
                if (tag.length > 50) {
                  return 'Pig tags must be 50 characters or less.';
                }
                return null;
              },
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'App-assigned tag'),
              child: Text(animal!.tag),
            ),
          if (isCreating) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Pig type'),
              items: const [
                DropdownMenuItem(value: 'sow', child: Text('Female pig')),
                DropdownMenuItem(value: 'piglet', child: Text('Piglet')),
                DropdownMenuItem(value: 'boar', child: Text('Male pig')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        _sex = switch (value) {
                          'boar' => 'male',
                          'sow' => 'female',
                          _ => 'unknown',
                        };
                        if (_sex != 'female') _isPregnant = false;
                      });
                    },
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Pig name (optional)'),
            validator: (value) => (value?.trim().length ?? 0) > 100
                ? 'Pig names must be 100 characters or less.'
                : null,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final weight = double.tryParse(value.trim());
              if (weight == null || weight <= 0) {
                return 'Enter a weight greater than zero.';
              }
              if (weight > 999999.99) {
                return 'Weight must be 999,999.99 kg or less.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (!isCreating || _type == 'piglet')
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'unknown', child: Text('Not set')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _sex = value;
                        if (_sex != 'female') _isPregnant = false;
                      });
                    },
            ),
          if (_sex == 'female')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pregnant'),
              value: _isPregnant,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _isPregnant = value),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Age / date of birth'),
            subtitle: Text(_dateLabel(_birthDate)),
            trailing: IconButton(
              tooltip: 'Set birth date',
              onPressed: _saving
                  ? null
                  : () => _pickDate(
                      current: _birthDate,
                      onSelected: (value) => setState(() => _birthDate = value),
                    ),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          const Divider(),
          Text('Health status', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Last dewormed'),
            subtitle: Text(_dateLabel(_lastDewormedAt)),
            trailing: IconButton(
              tooltip: 'Set last dewormed date',
              onPressed: _saving
                  ? null
                  : () => _pickDate(
                      current: _lastDewormedAt,
                      onSelected: (value) =>
                          setState(() => _lastDewormedAt = value),
                    ),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Last vaccinated'),
            subtitle: Text(_dateLabel(_lastVaccinatedAt)),
            trailing: IconButton(
              tooltip: 'Set last vaccinated date',
              onPressed: _saving
                  ? null
                  : () => _pickDate(
                      current: _lastVaccinatedAt,
                      onSelected: (value) =>
                          setState(() => _lastVaccinatedAt = value),
                    ),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Animal status'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'sold', child: Text('Sold')),
              DropdownMenuItem(value: 'deceased', child: Text('Deceased')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _status = value);
                  },
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            validator: (value) => (value?.length ?? 0) > 2000
                ? 'Notes must be 2,000 characters or less.'
                : null,
          ),
          if (!isCreating && _sex == 'female') ...[
            const SizedBox(height: AppDimensions.spacingLarge),
            _AnimalPregnancyReport(animalId: animal!.id),
          ],
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(AppDimensions.pagePadding),
      child: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(isCreating ? 'Add pig' : 'Save pig details'),
      ),
    ),
  );
}

class _AnimalPregnancyReport extends ConsumerWidget {
  const _AnimalPregnancyReport({required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pregnancy report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh pregnancy report',
                  onPressed: () => ref.invalidate(pregnancyProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            pregnancies.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Could not load pregnancy history: $error'),
                  TextButton(
                    onPressed: () => ref.invalidate(pregnancyProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (items) {
                final records = items
                    .where((item) => item.sowId == animalId)
                    .toList();
                if (records.isEmpty) {
                  return const Text('No pregnancy records for this pig yet.');
                }
                return Column(
                  children: [
                    for (final pregnancy in records)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.favorite_outline),
                        title: Text(
                          '${_titleCase(pregnancy.status)} · inseminated ${_formatDate(pregnancy.matingDate)}',
                        ),
                        subtitle: Text(
                          [
                            'Expected farrowing ${_formatDate(pregnancy.expectedFarrowingDate)}',
                            if (pregnancy.actualFarrowingDate != null)
                              'Farrowed ${_formatDate(pregnancy.actualFarrowingDate!)}',
                            if (pregnancy.expectedLitterSize != null)
                              'Expected litter ${pregnancy.expectedLitterSize}',
                            if (pregnancy.bornAlive != null)
                              'Born alive ${pregnancy.bornAlive}',
                            if (pregnancy.stillborn != null)
                              'Stillborn ${pregnancy.stillborn}',
                            if (pregnancy.mummified != null)
                              'Mummified ${pregnancy.mummified}',
                            if (pregnancy.weaned != null)
                              'Weaned ${pregnancy.weaned}',
                            if (pregnancy.notes?.trim().isNotEmpty == true)
                              pregnancy.notes!.trim(),
                          ].join(' · '),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

class _HerdSummary extends StatelessWidget {
  const _HerdSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _RegistrationSlot {
  const _RegistrationSlot({
    required this.type,
    required this.number,
    required this.suggestedTag,
  });

  final String type;
  final int number;
  final String suggestedTag;
}

class _RegistrationSlotsGrid extends StatelessWidget {
  const _RegistrationSlotsGrid({required this.slots, required this.onAdd});

  final List<_RegistrationSlot> slots;
  final ValueChanged<_RegistrationSlot> onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimensions.spacingMedium),
    decoration: BoxDecoration(
      color: AppColors.warningContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete registered pig details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${slots.length} registered pig${slots.length == 1 ? '' : 's'} still need individual records.',
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 340 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 142,
                crossAxisSpacing: AppDimensions.spacingMedium,
                mainAxisSpacing: AppDimensions.spacingMedium,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final isPiglet = slot.type == 'piglet';
                return Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radius),
                    onTap: () => onAdd(slot),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPiglet
                                    ? Icons.child_care_outlined
                                    : Icons.pets_outlined,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${isPiglet ? 'Piglet' : 'Female pig'} ${slot.number}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Suggested tag: ${slot.suggestedTag}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => onAdd(slot),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

String _nextPigTag(Iterable<Animal> animals, [Set<String>? reservedTags]) {
  final reserved =
      reservedTags ?? animals.map((animal) => animal.tag.toUpperCase()).toSet();
  var number = 1;
  while (true) {
    final tag = 'PIG-${number.toString().padLeft(3, '0')}';
    if (reserved.add(tag)) return tag;
    number++;
  }
}

Future<void> _autoFillRegisteredPigs(
  BuildContext context,
  WidgetRef ref, {
  required List<Animal> animals,
  required int registeredHerdCount,
  required int motherPigCount,
}) async {
  final remaining = (registeredHerdCount - animals.length).clamp(
    0,
    registeredHerdCount,
  );
  if (remaining == 0) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Auto-fill registered herd?'),
      content: Text(
        'Create $remaining active pig records with generated tags and default details? You can edit each pig and add photos later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Create $remaining pigs'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final progressDialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text('Creating $remaining pig records…')),
        ],
      ),
    ),
  );

  final reservedTags = animals
      .map((animal) => animal.tag.toUpperCase())
      .toSet();
  final remainingMothers =
      (motherPigCount - animals.where((animal) => animal.type == 'sow').length)
          .clamp(0, remaining);
  var created = 0;
  String? failedTag;
  Object? failure;
  for (var index = 0; index < remaining; index++) {
    final tag = _nextPigTag(animals, reservedTags);
    final isMother = index < remainingMothers;
    try {
      await ref
          .read(herdProvider.notifier)
          .createAnimal(
            tag: tag,
            type: isMother ? 'sow' : 'piglet',
            sex: isMother ? 'female' : 'unknown',
            status: 'active',
          );
      created++;
    } catch (error) {
      failedTag = tag;
      failure = error;
      break;
    }
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  await progressDialog;
  if (!context.mounted) return;

  final message = failure == null
      ? 'Created $created pig records.'
      : 'Created $created of $remaining pigs. Could not create $failedTag: $failure';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({
    required this.animal,
    required this.onEdit,
    required this.onArchive,
  });
  final Animal animal;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final active = animal.status == 'active';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 280;
          final photo = animal.imageUrl == null
              ? const ColoredBox(
                  color: AppColors.pigPink,
                  child: Center(
                    child: Icon(
                      Icons.pets_outlined,
                      size: 42,
                      color: AppColors.deepGreen,
                    ),
                  ),
                )
              : Image.network(
                  animal.imageUrl!,
                  key: ValueKey(animal.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.pigPink,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                animal.name?.isNotEmpty == true ? animal.name! : animal.tag,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (animal.name?.isNotEmpty == true)
                Text(animal.tag, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                '${animal.type} · ${animal.sex} · ${_ageLabel(animal.birthDate)}${animal.weightKg == null ? '' : ' · ${animal.weightKg} kg'}',
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _DetailChip(label: active ? 'Healthy' : animal.status),
                  const _DetailChip(label: 'Pen not set'),
                ],
              ),
            ],
          );
          if (horizontal) {
            return Row(
              children: [
                SizedBox(width: 112, height: double.infinity, child: photo),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: details,
                  ),
                ),
                _AnimalActions(onEdit: onEdit, onArchive: onArchive),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: photo),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    _AnimalActions(onEdit: onEdit, onArchive: onArchive),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimalActions extends StatelessWidget {
  const _AnimalActions({required this.onEdit, required this.onArchive});

  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'edit') onEdit();
      if (value == 'archive') onArchive();
    },
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'edit', child: Text('Edit')),
      PopupMenuItem(value: 'archive', child: Text('Delete / archive')),
    ],
  );
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

String _ageLabel(DateTime? birthDate) {
  if (birthDate == null) return 'Age not set';
  final days = DateTime.now().difference(birthDate).inDays;
  return days < 365
      ? '${(days / 30).floor()} mo'
      : '${(days / 365).floor()} yr';
}
