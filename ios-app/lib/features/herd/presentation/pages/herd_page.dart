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

class HerdPage extends ConsumerStatefulWidget {
  const HerdPage({super.key});

  @override
  ConsumerState<HerdPage> createState() => _HerdPageState();
}

class _HerdPageState extends ConsumerState<HerdPage> {
  late final TextEditingController _tagController;
  late final TextEditingController _notesController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _notesController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          if (remainingRegistrationCount == 0)
            FloatingActionButton.extended(
              heroTag: 'add-herd-pig',
              onPressed: () => _showAddAnimalDialog(context, ref),
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
              final displayedHerdCount = animals.length;
              final remainingCount = registeredHerdCount > animals.length
                  ? registeredHerdCount - animals.length
                  : 0;
              final registeredMothers = animals
                  .where((animal) => animal.type == 'sow')
                  .length;
              final remainingMotherCount =
                  (registeredFarm?.motherPigCount ?? 0) - registeredMothers;
              final requiredMotherDetails = remainingMotherCount
                  .clamp(0, remainingCount)
                  .toInt();
              final requiredPigletDetails =
                  remainingCount - requiredMotherDetails;
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
                      label: 'Details entered',
                      value: '$displayedHerdCount',
                      icon: Icons.pets_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    if (remainingCount > 0) ...[
                      const SizedBox(height: AppDimensions.spacingMedium),
                      _RegistrationDetailsGrid(
                        key: ValueKey(
                          'registered-herd-$registeredHerdCount-${animals.length}',
                        ),
                        remainingMotherCount: requiredMotherDetails,
                        remainingPigletCount: requiredPigletDetails,
                        firstTagNumber: animals.length + 1,
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
                      ...filteredAnimals.map(
                        (animal) => _AnimalCard(
                          animal: animal,
                          onEdit: () =>
                              _showEditAnimalDialog(context, ref, animal),
                          onArchive: () => _archiveAnimal(context, ref, animal),
                          onPregnancyReport: () => showDialog<void>(
                            context: context,
                            builder: (_) => _AnimalPregnancyReportDialog(
                              animalId: animal.id,
                              animalTag: animal.tag,
                            ),
                          ),
                        ),
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

  Future<void> _showAddAnimalDialog(BuildContext context, WidgetRef ref) async {
    _tagController.clear();
    _notesController.clear();
    _weightController.clear();
    final tagController = _tagController;
    final notesController = _notesController;
    final weightController = _weightController;
    DateTime? birthDate;
    XFile? image;
    String type = 'sow';
    String sex = 'female';
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add pig'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tagController,
                    decoration: const InputDecoration(labelText: 'Tag'),
                    validator: (value) {
                      final tag = value?.trim() ?? '';
                      if (tag.isEmpty) return 'Enter an animal tag.';
                      if (tag.length > 50) {
                        return 'Pig tags must be 50 characters or less.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    validator: (value) {
                      final weight = double.tryParse(value?.trim() ?? '');
                      if (weight == null || weight <= 0) {
                        return 'Enter a weight greater than zero.';
                      }
                      if (weight > 999999.99) {
                        return 'Weight must be 999,999.99 kg or less.';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'boar', child: Text('Male pig')),
                      DropdownMenuItem(value: 'sow', child: Text('Female pig')),
                      DropdownMenuItem(value: 'piglet', child: Text('Piglet')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        type = value;
                        sex = switch (value) {
                          'boar' => 'male',
                          'sow' => 'female',
                          _ => 'unknown',
                        };
                      });
                    },
                  ),
                  if (type == 'piglet')
                    DropdownButtonFormField<String>(
                      initialValue: sex,
                      decoration: const InputDecoration(labelText: 'Sex'),
                      items: const [
                        DropdownMenuItem(
                          value: 'unknown',
                          child: Text('Not set'),
                        ),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (value) => setState(() => sex = value ?? sex),
                    ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    validator: (value) => (value?.length ?? 0) > 2000
                        ? 'Notes must be 2,000 characters or less.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(1990),
                          lastDate: DateTime.now(),
                          initialDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => birthDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        birthDate == null
                            ? 'Add birth date'
                            : 'Born ${birthDate!.day}/${birthDate!.month}/${birthDate!.year}',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1600,
                          imageQuality: 80,
                        );
                        if (picked != null) setState(() => image = picked);
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        image == null ? 'Add a photo' : 'Photo added',
                      ),
                    ),
                  ),
                  if (image != null)
                    FutureBuilder(
                      future: image!.readAsBytes(),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Image.memory(
                              snapshot.data!,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  final imageBytes = image == null
                      ? null
                      : await image!.readAsBytes();
                  if (imageBytes != null &&
                      imageBytes.length > 5 * 1024 * 1024) {
                    throw StateError('Pig photos must be 5 MB or smaller.');
                  }
                  await ref
                      .read(herdProvider.notifier)
                      .createAnimal(
                        tag: tagController.text.trim(),
                        type: type,
                        sex: sex,
                        birthDate: birthDate,
                        weightKg: double.parse(weightController.text),
                        notes: notesController.text,
                        imageBytes: imageBytes,
                        imageName: image?.name,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not add pig: $error')),
                    );
                  }
                }
              },
              child: const Text('Add pig'),
            ),
          ],
        ),
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
    _tagController.text = animal.tag;
    _notesController.text = animal.notes ?? '';
    final tagController = _tagController;
    final notesController = _notesController;
    String status = animal.status;
    XFile? image;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${animal.tag}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(labelText: 'Tag'),
                  maxLength: 50,
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'sold', child: Text('Sold')),
                    DropdownMenuItem(
                      value: 'deceased',
                      child: Text('Deceased'),
                    ),
                  ],
                  onChanged: (value) => status = value ?? status,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                if (image != null)
                  FutureBuilder(
                    future: image!.readAsBytes(),
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  )
                else if (animal.imageUrl != null)
                  Image.network(
                    animal.imageUrl!,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.pets_outlined, size: 48),
                  )
                else
                  const Icon(Icons.pets_outlined, size: 48),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 80,
                    );
                    if (picked != null) setState(() => image = picked);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    image == null ? 'Change photo' : 'Choose another photo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (tagController.text.trim().isEmpty) return;
                try {
                  final imageBytes = image == null
                      ? null
                      : await image!.readAsBytes();
                  if (imageBytes != null &&
                      imageBytes.length > 5 * 1024 * 1024) {
                    throw StateError('Pig photos must be 5 MB or smaller.');
                  }
                  await ref
                      .read(herdProvider.notifier)
                      .updateAnimal(
                        animalId: animal.id,
                        tag: tagController.text,
                        status: status,
                        notes: notesController.text,
                        imageBytes: imageBytes,
                        imageName: image?.name,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not update animal: $error'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
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

class _RegistrationDetailsGrid extends ConsumerStatefulWidget {
  const _RegistrationDetailsGrid({
    super.key,
    required this.remainingMotherCount,
    required this.remainingPigletCount,
    required this.firstTagNumber,
  });

  final int remainingMotherCount;
  final int remainingPigletCount;
  final int firstTagNumber;

  @override
  ConsumerState<_RegistrationDetailsGrid> createState() =>
      _RegistrationDetailsGridState();
}

class _RegistrationDetailsGridState
    extends ConsumerState<_RegistrationDetailsGrid> {
  late final List<_AnimalDraft> _drafts;

  @override
  void initState() {
    super.initState();
    final motherCount = widget.remainingMotherCount;
    final totalCount = motherCount + widget.remainingPigletCount;
    _drafts = List.generate(totalCount, (index) {
      final isPiglet = index >= motherCount;
      return _AnimalDraft(
        tag:
            'PIG-${(widget.firstTagNumber + index).toString().padLeft(3, '0')}',
        type: isPiglet ? 'piglet' : 'sow',
        sex: isPiglet ? 'unknown' : 'female',
      );
    });
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDraft(_AnimalDraft draft) async {
    if (draft.tagController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a tag for this pig.')),
      );
      return;
    }
    setState(() => draft.isSaving = true);
    try {
      await ref
          .read(herdProvider.notifier)
          .createAnimal(
            tag: draft.tagController.text.trim(),
            type: draft.type,
            sex: draft.sex,
            imageBytes: draft.image == null
                ? null
                : await draft.image!.readAsBytes(),
            imageName: draft.image?.name,
          );
      if (!mounted) return;
      setState(() {
        draft.isSaving = false;
        draft.isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.tagController.text} saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => draft.isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save ${draft.tagController.text}: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_drafts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.warningContainer.withValues(alpha: 0.55),
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
            '${_drafts.length} pigs still need individual records. Add each pig to finish your farm setup.',
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _drafts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 242,
                  crossAxisSpacing: AppDimensions.spacingMedium,
                  mainAxisSpacing: AppDimensions.spacingMedium,
                ),
                itemBuilder: (context, index) => _RegistrationAnimalCard(
                  number: index + 1,
                  draft: _drafts[index],
                  onChanged: () => setState(() {}),
                  onSave: () => _saveDraft(_drafts[index]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimalDraft {
  _AnimalDraft({required String tag, required this.type, required this.sex})
    : tagController = TextEditingController(text: tag);

  final TextEditingController tagController;
  String type;
  String sex;
  XFile? image;
  bool isSaving = false;
  bool isSaved = false;

  void dispose() => tagController.dispose();
}

class _RegistrationAnimalCard extends StatelessWidget {
  const _RegistrationAnimalCard({
    required this.number,
    required this.draft,
    required this.onChanged,
    required this.onSave,
  });

  final int number;
  final _AnimalDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pig $number', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          TextFormField(
            controller: draft.tagController,
            decoration: const InputDecoration(
              labelText: 'Tag',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'boar', child: Text('Male pig')),
                    DropdownMenuItem(value: 'sow', child: Text('Female pig')),
                    DropdownMenuItem(value: 'piglet', child: Text('Piglet')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    draft.type = value;
                    draft.sex = switch (value) {
                      'boar' => 'male',
                      'sow' => 'female',
                      _ => 'unknown',
                    };
                    onChanged();
                  },
                ),
              ),
              if (draft.type == 'piglet') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.sex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sex',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Not set'),
                      ),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      draft.sex = value;
                      onChanged();
                    },
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (draft.image != null)
                FutureBuilder(
                  future: draft.image!.readAsBytes(),
                  builder: (context, snapshot) => snapshot.hasData
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const SizedBox(width: 38, height: 38),
                )
              else
                IconButton(
                  tooltip: 'Add photo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      draft.image = picked;
                      onChanged();
                    }
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              const Spacer(),
              FilledButton(
                onPressed: draft.isSaving || draft.isSaved ? null : onSave,
                child: draft.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(draft.isSaved ? 'Saved' : 'Save details'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({
    required this.animal,
    required this.onEdit,
    required this.onArchive,
    required this.onPregnancyReport,
  });
  final Animal animal;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onPregnancyReport;

  @override
  Widget build(BuildContext context) {
    final active = animal.status == 'active';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.pigPink.withValues(alpha: 0.25),
              backgroundImage: animal.imageUrl == null
                  ? null
                  : NetworkImage(animal.imageUrl!),
              child: animal.imageUrl == null
                  ? const Icon(Icons.pets_outlined, color: AppColors.deepGreen)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animal.tag,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'archive') onArchive();
                if (value == 'pregnancy-report') onPregnancyReport();
              },
              itemBuilder: (context) => [
                if (animal.sex.trim().toLowerCase() == 'female')
                  const PopupMenuItem(
                    value: 'pregnancy-report',
                    child: Text('Pregnancy report'),
                  ),
                const PopupMenuItem(value: 'view', child: Text('View profile')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Delete / archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalPregnancyReportDialog extends ConsumerWidget {
  const _AnimalPregnancyReportDialog({
    required this.animalId,
    required this.animalTag,
  });

  final String animalId;
  final String animalTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);
    return AlertDialog(
      title: Text('$animalTag pregnancy report'),
      content: SizedBox(
        width: 460,
        child: pregnancies.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
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
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final pregnancy in records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite_outline),
                      title: Text(
                        '${pregnancy.status.replaceAll('_', ' ')} · inseminated ${_date(pregnancy.matingDate)}',
                      ),
                      subtitle: Text(
                        [
                          'Expected farrowing ${_date(pregnancy.expectedFarrowingDate)}',
                          if (pregnancy.actualFarrowingDate != null)
                            'Farrowed ${_date(pregnancy.actualFarrowingDate!)}',
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
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
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
