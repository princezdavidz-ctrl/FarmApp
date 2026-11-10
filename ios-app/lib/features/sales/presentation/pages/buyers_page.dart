import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../features/auth/domain/entities/session.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/settings/presentation/providers/farm_access_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../../data/farm_buyer.dart';
import '../providers/farm_sales_provider.dart';

class BuyersPage extends ConsumerStatefulWidget {
  const BuyersPage({super.key});

  @override
  ConsumerState<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends ConsumerState<BuyersPage> {
  String _search = '';

  bool _canManage(Session? session, FarmAccessState? access) {
    if (session?.user.role == UserRole.farmOwner) return true;
    return session != null &&
        access
                ?.permissionsFor(session.user.id)
                .contains(AppPermission.manageSales) ==
            true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authProvider).valueOrNull;
    final access = ref.watch(farmAccessProvider).valueOrNull;
    final state = ref.watch(farmSalesProvider);
    final canManage = _canManage(session, access);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.buyers),
        leading: IconButton(
          tooltip: l10n.sales,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.salesAndExpenses),
        ),
      ),
      floatingActionButton: canManage && session?.selectedFarm != null
          ? FloatingActionButton.extended(
              onPressed: () => _showBuyerDialog(),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.addBuyer),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(farmSalesProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: l10n.buyerSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            if (session?.selectedFarm == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l10n.selectFarm),
                ),
              )
            else
              state.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '${l10n.salesLoadError}\n$error',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(farmSalesProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  final buyers = data.buyers
                      .where((buyer) => _matches(buyer, _search))
                      .toList();
                  if (buyers.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              _search.isEmpty
                                  ? l10n.noBuyers
                                  : l10n.noBuyersMatchSearch,
                              textAlign: TextAlign.center,
                            ),
                            if (_search.isEmpty && canManage)
                              TextButton(
                                onPressed: () => _showBuyerDialog(),
                                child: Text(l10n.addBuyer),
                              ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final buyer in buyers)
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(buyer.name),
                            subtitle: Text(
                              [
                                if (buyer.company != null &&
                                    buyer.company!.isNotEmpty)
                                  buyer.company!,
                                if (buyer.phone != null &&
                                    buyer.phone!.isNotEmpty)
                                  buyer.phone!,
                                if (buyer.email != null &&
                                    buyer.email!.isNotEmpty)
                                  buyer.email!,
                              ].join(' · '),
                            ),
                            trailing: canManage
                                ? IconButton(
                                    tooltip: l10n.editBuyer,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showBuyerDialog(buyer: buyer),
                                  )
                                : null,
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

  bool _matches(FarmBuyer buyer, String query) {
    if (query.isEmpty) return true;
    return [
      buyer.name,
      buyer.email ?? '',
      buyer.phone ?? '',
      buyer.company ?? '',
    ].any((value) => value.toLowerCase().contains(query));
  }

  Future<void> _showBuyerDialog({FarmBuyer? buyer}) async {
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: buyer?.name ?? '');
    final email = TextEditingController(text: buyer?.email ?? '');
    final phone = TextEditingController(text: buyer?.phone ?? '');
    final company = TextEditingController(text: buyer?.company ?? '');
    final address = TextEditingController(text: buyer?.address ?? '');
    final notes = TextEditingController(text: buyer?.notes ?? '');
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(buyer == null ? l10n.addBuyer : l10n.editBuyer),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(labelText: l10n.buyerName),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.buyerNameRequired
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: InputDecoration(labelText: l10n.buyerPhone),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: email,
                      decoration: InputDecoration(labelText: l10n.buyerEmail),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        return value.contains('@') ? null : l10n.invalidEmail;
                      },
                    ),
                    TextFormField(
                      controller: company,
                      decoration: InputDecoration(labelText: l10n.buyerCompany),
                    ),
                    TextFormField(
                      controller: address,
                      decoration: InputDecoration(labelText: l10n.buyerAddress),
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: InputDecoration(labelText: l10n.saleNotes),
                      maxLines: 2,
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final values = {
                        'name': name.text.trim(),
                        'email': email.text.trim().isEmpty
                            ? null
                            : email.text.trim(),
                        'phone': phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        'company': company.text.trim().isEmpty
                            ? null
                            : company.text.trim(),
                        'address': address.text.trim().isEmpty
                            ? null
                            : address.text.trim(),
                        'notes': notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                      };
                      try {
                        if (buyer == null) {
                          await ref
                              .read(farmSalesProvider.notifier)
                              .createBuyer(
                                name: name.text.trim(),
                                email: email.text.trim().isEmpty
                                    ? null
                                    : email.text.trim(),
                                phone: phone.text.trim().isEmpty
                                    ? null
                                    : phone.text.trim(),
                                company: company.text.trim().isEmpty
                                    ? null
                                    : company.text.trim(),
                                address: address.text.trim().isEmpty
                                    ? null
                                    : address.text.trim(),
                                notes: notes.text.trim().isEmpty
                                    ? null
                                    : notes.text.trim(),
                              );
                        } else {
                          await ref
                              .read(farmSalesProvider.notifier)
                              .updateBuyer(buyer.id, values);
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                  : Text(l10n.saveTask),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
    company.dispose();
    address.dispose();
    notes.dispose();
  }
}
