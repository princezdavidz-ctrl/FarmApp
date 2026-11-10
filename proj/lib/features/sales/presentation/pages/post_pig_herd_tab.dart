import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';
import '../providers/pig_marketplace_provider.dart';

class PostPigHerdTab extends ConsumerStatefulWidget {
  const PostPigHerdTab({required this.canManage, super.key});

  final bool canManage;

  @override
  ConsumerState<PostPigHerdTab> createState() => _PostPigHerdTabState();
}

class _PostPigHerdTabState extends ConsumerState<PostPigHerdTab> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFarm = ref.watch(authProvider).valueOrNull?.selectedFarm != null;
    final herd = ref.watch(herdProvider);
    final listings = ref.watch(pigMarketplaceProvider);
    final postedIds =
        listings.valueOrNull
            ?.where((listing) => listing.status == 'available')
            .map((listing) => listing.animalId)
            .whereType<String>()
            .toSet() ??
        const <String>{};

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => DefaultTabController.of(context).animateTo(2),
        icon: const Icon(Icons.checklist_outlined),
        label: const Text('Posted'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(herdProvider.future),
            ref.refresh(pigMarketplaceProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pagePadding,
            AppDimensions.pagePadding,
            AppDimensions.pagePadding,
            100,
          ),
          children: [
            Text(
              'Select a pig to post',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const Text(
              'Choose an active animal from your Herd. Its saved photo and details will appear in the buyer listing.',
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search your pigs',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            if (!hasFarm)
              const _PostMessage('Select a farm before posting pigs.')
            else if (!widget.canManage)
              const _PostMessage(
                'You need Manage sales permission to post pigs.',
              )
            else
              herd.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => _PostMessage(
                  'Your Herd could not be loaded: $error',
                  action: TextButton(
                    onPressed: () => ref.invalidate(herdProvider),
                    child: const Text('Retry'),
                  ),
                ),
                data: (animals) {
                  final available = animals.where((animal) {
                    if (animal.status != 'active') return false;
                    if (_search.isEmpty) return true;
                    return '${animal.tag} ${animal.type} ${animal.sex}'
                        .toLowerCase()
                        .contains(_search.toLowerCase());
                  }).toList();
                  if (available.isEmpty) {
                    return _PostMessage(
                      _search.isEmpty
                          ? 'No active pigs are available to post.'
                          : 'No Herd pigs match your search.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 700
                          ? 3
                          : constraints.maxWidth >= 380
                          ? 2
                          : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: available.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppDimensions.spacingMedium,
                          mainAxisSpacing: AppDimensions.spacingMedium,
                          childAspectRatio: columns == 1 ? 2.1 : 0.78,
                        ),
                        itemBuilder: (context, index) => _PostPigCard(
                          animal: available[index],
                          isPosted: postedIds.contains(available[index].id),
                          onPost: () => _showPostDialog(available[index]),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPostDialog(Animal animal) async {
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    var currency = 'KES';
    var saving = false;
    String? error;
    Uint8List? replacementImage;
    String? replacementImageName;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Post ${animal.tag}'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AnimalPhoto(
                      animal: animal,
                      height: 150,
                      replacementImage: replacementImage,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1600,
                                  imageQuality: 85,
                                );
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                if (bytes.length > 5 * 1024 * 1024) {
                                  setDialogState(() {
                                    error =
                                        'Pig photos must be 5 MB or smaller.';
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  replacementImage = bytes;
                                  replacementImageName = picked.name;
                                  error = null;
                                });
                              } catch (exception) {
                                setDialogState(() {
                                  error =
                                      'Could not load pig photo: $exception';
                                });
                              }
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        replacementImage == null
                            ? animal.imageUrl == null
                                  ? 'Choose pig photo'
                                  : 'Replace Herd photo'
                            : 'Choose another photo',
                      ),
                    ),
                    const Text(
                      'A new photo will replace this pig’s saved Herd photo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price for this pig',
                      ),
                      validator: (value) {
                        final price = double.tryParse(value?.trim() ?? '');
                        return price == null || price <= 0
                            ? 'Enter a price greater than zero.'
                            : null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: const [
                        DropdownMenuItem(value: 'KES', child: Text('KES')),
                        DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                        DropdownMenuItem(value: 'TZS', child: Text('TZS')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => currency = value ?? currency),
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          if (animal.imageUrl == null &&
                              replacementImage == null) {
                            setDialogState(() {
                              saving = false;
                              error =
                                  'Choose a photo for this pig before posting.';
                            });
                            return;
                          }
                          final ageWeeks = animal.birthDate == null
                              ? null
                              : (DateTime.now()
                                            .difference(animal.birthDate!)
                                            .inDays ~/
                                        7)
                                    .clamp(1, 156)
                                    .toInt();
                          if (replacementImage != null) {
                            await ref
                                .read(herdProvider.notifier)
                                .updateAnimal(
                                  animalId: animal.id,
                                  imageBytes: replacementImage,
                                  imageName: replacementImageName,
                                );
                          }
                          await ref
                              .read(pigMarketplaceProvider.notifier)
                              .createListing(
                                animalId: animal.id,
                                title: animal.tag,
                                breed: '${animal.type} (${animal.sex})',
                                quantity: 1,
                                pricePerPig: double.parse(
                                  priceController.text.trim(),
                                ),
                                currency: currency,
                                ageWeeks: ageWeeks,
                                weightKg: animal.weightKg,
                                description: descriptionController.text.trim(),
                              );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${animal.tag} posted for buyers.',
                                ),
                              ),
                            );
                          }
                        } catch (exception) {
                          setDialogState(() {
                            saving = false;
                            error = '$exception';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ),
      );
    } finally {
      priceController.dispose();
      descriptionController.dispose();
    }
  }
}

class _PostPigCard extends StatelessWidget {
  const _PostPigCard({
    required this.animal,
    required this.isPosted,
    required this.onPost,
  });

  final Animal animal;
  final bool isPosted;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 280;
          final photo = _AnimalPhoto(animal: animal);
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(animal.tag, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('${animal.type} · ${animal.sex}'),
              if (animal.weightKg != null) Text('${animal.weightKg} kg'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: isPosted
                    ? const OutlinedButton(
                        onPressed: null,
                        child: Text('Posted'),
                      )
                    : FilledButton.icon(
                        onPressed: onPost,
                        icon: const Icon(Icons.publish_outlined),
                        label: const Text('Post'),
                      ),
              ),
            ],
          );
          return horizontal
              ? Row(
                  children: [
                    SizedBox(width: 112, height: double.infinity, child: photo),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: details,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: photo),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: details,
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class _AnimalPhoto extends StatelessWidget {
  const _AnimalPhoto({
    required this.animal,
    this.height,
    this.replacementImage,
  });

  final Animal animal;
  final double? height;
  final Uint8List? replacementImage;

  @override
  Widget build(BuildContext context) {
    final url = animal.imageUrl;
    final image = replacementImage != null
        ? Image.memory(replacementImage!, fit: BoxFit.cover)
        : url == null || url.isEmpty
        ? const ColoredBox(
            color: Color(0xFFF6DCE4),
            child: Center(child: Icon(Icons.pets_outlined, size: 40)),
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFF6DCE4),
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
    if (height == null) return SizedBox.expand(child: image);
    return SizedBox(height: height, width: double.infinity, child: image);
  }
}

class _PostMessage extends StatelessWidget {
  const _PostMessage(this.message, {this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
