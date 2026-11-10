import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/pig_listing.dart';
import '../providers/pig_marketplace_provider.dart';

class ForBuyersTab extends ConsumerWidget {
  const ForBuyersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(pigMarketplaceProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(pigMarketplaceProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryGreen, AppColors.deepGreen],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepGreen.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'FARM MARKETPLACE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your farm on the pig marketplace',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Showcase healthy pigs to buyers and keep track of their requests.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          listings.when(
            loading: () => const _MarketplaceMessage(
              message: 'Finding pigs available from farms…',
              icon: Icons.search,
              loading: true,
            ),
            error: (error, _) => _MarketplaceMessage(
              message: 'Marketplace listings could not be loaded: $error',
              action: TextButton(
                onPressed: () => ref.invalidate(pigMarketplaceProvider),
                child: const Text('Retry'),
              ),
            ),
            data: (items) {
              final available = items
                  .where((listing) => listing.status == 'available')
                  .toList();
              if (available.isEmpty) {
                return const _MarketplaceMessage(
                  message:
                      'No pigs are listed yet. Post a pig to make it visible to buyers.',
                );
              }
              return Column(
                children: [
                  for (final listing in available)
                    _ListingCard(listing: listing),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PostPigTab extends ConsumerStatefulWidget {
  const PostPigTab({required this.canManage, super.key});

  final bool canManage;

  @override
  ConsumerState<PostPigTab> createState() => _PostPigTabState();
}

class _PostPigTabState extends ConsumerState<PostPigTab> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _breed = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _currency = 'KES';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _breed.dispose();
    _quantity.dispose();
    _price.dispose();
    _age.dispose();
    _weight.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFarm = ref.watch(authProvider).valueOrNull?.selectedFarm != null;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_business_outlined,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post a pig for sale',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a listing buyers can discover in the marketplace.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (!hasFarm)
          const _MarketplaceMessage(
            message: 'Select a farm before posting pigs.',
            icon: Icons.agriculture_outlined,
          )
        else if (!widget.canManage)
          const _MarketplaceMessage(
            message: 'You need Manage sales permission to post pigs.',
            icon: Icons.lock_outline,
          )
        else
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormSectionLabel(
                      icon: Icons.sell_outlined,
                      title: 'Listing details',
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Listing title',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    _FormSectionLabel(
                      icon: Icons.pets_outlined,
                      title: 'Pig details',
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    TextFormField(
                      controller: _breed,
                      decoration: const InputDecoration(labelText: 'Breed'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number available',
                            ),
                            validator: _positiveInteger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age (weeks)',
                            ),
                            validator: _optionalPositiveInteger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormSectionLabel(
                      icon: Icons.payments_outlined,
                      title: 'Pricing',
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price per pig',
                            ),
                            validator: _positiveNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'KES',
                                child: Text('KES'),
                              ),
                              DropdownMenuItem(
                                value: 'UGX',
                                child: Text('UGX'),
                              ),
                              DropdownMenuItem(
                                value: 'TZS',
                                child: Text('TZS'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('USD'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _currency = value ?? _currency),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormSectionLabel(
                      icon: Icons.notes_outlined,
                      title: 'More information',
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Average weight (kg, optional)',
                      ),
                      validator: _optionalPositiveNumber,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.publish_outlined),
                        label: Text(_saving ? 'Posting…' : 'Publish listing'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1 ? 'Enter a number above zero.' : null;
  }

  String? _optionalPositiveInteger(String? value) =>
      value == null || value.trim().isEmpty ? null : _positiveInteger(value);

  String? _positiveNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'Enter an amount above zero.' : null;
  }

  String? _optionalPositiveNumber(String? value) =>
      value == null || value.trim().isEmpty ? null : _positiveNumber(value);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(pigMarketplaceProvider.notifier)
          .createListing(
            title: _title.text.trim(),
            breed: _breed.text.trim(),
            quantity: int.parse(_quantity.text.trim()),
            pricePerPig: double.parse(_price.text.trim()),
            currency: _currency,
            ageWeeks: int.tryParse(_age.text.trim()),
            weightKg: double.tryParse(_weight.text.trim()),
            location: _location.text.trim(),
            description: _description.text.trim(),
          );
      if (!mounted) return;
      _title.clear();
      _breed.clear();
      _quantity.text = '1';
      _price.clear();
      _age.clear();
      _weight.clear();
      _location.clear();
      _description.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pig listing published for buyers.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish listing: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class MyMarketplaceSalesSection extends ConsumerWidget {
  const MyMarketplaceSalesSection({required this.canManage, super.key});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pigMarketplaceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacingLarge),
        Text(
          'Marketplace listings & buyer requests',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        state.when(
          loading: () => const _MarketplaceMessage(
            message: 'Loading your listings and buyer requests…',
            icon: Icons.sync,
            loading: true,
          ),
          error: (error, _) => _MarketplaceMessage(
            message: 'Marketplace listings could not be loaded: $error',
            action: TextButton(
              onPressed: () => ref.invalidate(pigMarketplaceProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (items) => items.isEmpty
              ? const _MarketplaceMessage(
                  message: 'You have not posted any pigs yet.',
                )
              : Column(
                  children: [
                    for (final listing in items)
                      _ManageListingCard(
                        listing: listing,
                        canManage: canManage,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});

  final PigListing listing;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listing.imageUrl?.isNotEmpty == true)
          Image.network(
            listing.imageUrl!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _ListingImagePlaceholder(),
          )
        else
          _ListingImagePlaceholder(),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSmall),
                  Text(
                    '${listing.currency} ${listing.pricePerPig.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share pig listing',
                    onPressed: () => _shareListing(context, listing),
                    icon: const Icon(Icons.share_outlined),
                  ),
                ],
              ),
              if (listing.animalId?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  'Pig ID: ${listing.animalId}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
              const SizedBox(height: 7),
              Text(
                '${listing.breed} · ${listing.quantity} available'
                '${listing.location == null || listing.location!.isEmpty ? '' : ' · ${listing.location}'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
              if (listing.weightKg != null || listing.ageWeeks != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (listing.weightKg != null)
                      _ListingDetailChip(
                        label: '${listing.weightKg!.toStringAsFixed(1)} kg',
                      ),
                    if (listing.ageWeeks != null)
                      _ListingDetailChip(label: '${listing.ageWeeks} weeks'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ListingImagePlaceholder extends StatelessWidget {
  const _ListingImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryContainer, AppColors.background],
      ),
    ),
    alignment: Alignment.center,
    child: Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.pets_outlined,
        size: 34,
        color: AppColors.primaryGreen,
      ),
    ),
  );
}

class _ListingDetailChip extends StatelessWidget {
  const _ListingDetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.deepGreen,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ManageListingCard extends ConsumerWidget {
  const _ManageListingCard({required this.listing, required this.canManage});

  final PigListing listing;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (listing.imageUrl != null &&
                        listing.imageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            listing.imageUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(Icons.pets_outlined),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        listing.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (status) async {
                    try {
                      await ref
                          .read(pigMarketplaceProvider.notifier)
                          .updateListingStatus(listing.id, status);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not update listing: $error'),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'available', child: Text('Available')),
                    PopupMenuItem(
                      value: 'unavailable',
                      child: Text('Unavailable'),
                    ),
                    PopupMenuItem(value: 'sold', child: Text('Sold')),
                  ],
                  child: Chip(label: Text(listing.status)),
                )
              else
                Chip(label: Text(listing.status)),
              IconButton(
                tooltip: 'Share pig listing',
                onPressed: () => _shareListing(context, listing),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          Text(
            '${listing.breed} · ${listing.quantity} available · '
            '${listing.currency} ${listing.pricePerPig.toStringAsFixed(0)} each',
          ),
          if (listing.animalId?.isNotEmpty == true)
            Text('Pig ID: ${listing.animalId}'),
          for (final inquiry in listing.inquiries)
            _InquiryRow(
              listing: listing,
              inquiry: inquiry,
              canManage: canManage,
            ),
          if (listing.inquiries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No buyer requests yet.'),
            ),
        ],
      ),
    ),
  );
}

class _InquiryRow extends ConsumerWidget {
  const _InquiryRow({
    required this.listing,
    required this.inquiry,
    required this.canManage,
  });

  final PigListing listing;
  final PigInquiry inquiry;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('${inquiry.buyerName} · ${inquiry.quantity} requested'),
    subtitle: Text(
      '${inquiry.phone}${inquiry.message?.isNotEmpty == true ? '\n${inquiry.message}' : ''}',
    ),
    trailing: canManage
        ? PopupMenuButton<String>(
            onSelected: (status) async {
              try {
                await ref
                    .read(pigMarketplaceProvider.notifier)
                    .updateInquiryStatus(listing.id, inquiry.id, status);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update request: $error')),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'accepted', child: Text('Accepted')),
              PopupMenuItem(value: 'rejected', child: Text('Rejected')),
              PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
            child: Chip(label: Text(inquiry.status)),
          )
        : Chip(label: Text(inquiry.status)),
  );
}

Future<void> _shareListing(BuildContext context, PigListing listing) async {
  try {
    final renderObject = context.findRenderObject();
    await SharePlus.instance.share(
      ShareParams(
        text: listing.shareText,
        subject: listing.title,
        sharePositionOrigin: renderObject is RenderBox
            ? renderObject.localToGlobal(Offset.zero) & renderObject.size
            : null,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share pig listing: $error')),
      );
    }
  }
}

class _MarketplaceMessage extends StatelessWidget {
  const _MarketplaceMessage({
    required this.message,
    this.action,
    this.icon = Icons.storefront_outlined,
    this.loading = false,
  });

  final String message;
  final Widget? action;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: AppColors.deepGreen),
            ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedText,
              height: 1.4,
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.primaryGreen),
      const SizedBox(width: AppDimensions.spacingSmall),
      Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
