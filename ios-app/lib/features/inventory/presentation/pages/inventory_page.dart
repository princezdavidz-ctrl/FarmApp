import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/inventory/presentation/pages/sections/inventory_overview_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/search_categories_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/stock_items_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/suppliers_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/stock_movements_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/alerts_section.dart';
import 'package:proj/features/inventory/presentation/pages/sections/feed_stock_section.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Search', icon: Icon(Icons.search)),
            Tab(text: 'Stock Items', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Suppliers', icon: Icon(Icons.local_shipping_outlined)),
            Tab(text: 'Movements', icon: Icon(Icons.swap_horiz)),
            Tab(text: 'Alerts', icon: Icon(Icons.notifications_outlined)),
            Tab(text: 'Feed Stock', icon: Icon(Icons.grass_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const InventoryOverviewSection(),
          const SearchCategoriesSection(),
          const StockItemsSection(),
          const SuppliersSection(),
          const StockMovementsSection(),
          const AlertsSection(),
          const FeedStockSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final minimumController = TextEditingController(text: '0');
    final costController = TextEditingController(text: '0');
    final supplierController = TextEditingController();
    final locationController = TextEditingController();
    final barcodeController = TextEditingController();
    final notesController = TextEditingController();
    String category = 'Feed';
    String unit = 'kg';
    DateTime? expiryDate;

    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add inventory item'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an item name.'
                          : null,
                    ),
                    TextFormField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an SKU.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items:
                          const [
                                'Feed',
                                'Medicine',
                                'Vaccines',
                                'Equipment',
                                'Cleaning',
                                'Other',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => category = value ?? category),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items:
                                const [
                                      'kg',
                                      'liters',
                                      'bottles',
                                      'pieces',
                                      'bags',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) =>
                                setState(() => unit = value ?? unit),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: minimumController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Minimum level',
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cost price',
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Storage location (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                      maxLines: 2,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                            initialDate: expiryDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => expiryDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          expiryDate == null
                              ? 'Add expiry date'
                              : 'Expires ${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  try {
                    await ref
                        .read(createInventoryItemProvider.notifier)
                        .createItem(
                          name: nameController.text.trim(),
                          category: category,
                          sku: skuController.text.trim(),
                          quantity: double.parse(quantityController.text),
                          unit: unit,
                          minimumLevel: double.parse(minimumController.text),
                          costPrice: double.parse(costController.text),
                          supplier: _optionalValue(supplierController.text),
                          expiryDate: expiryDate,
                          storageLocation: _optionalValue(
                            locationController.text,
                          ),
                          barcode: _optionalValue(barcodeController.text),
                          notes: _optionalValue(notesController.text),
                        );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
                child: const Text('Add item'),
              ),
            ],
          ),
        ),
      );
      if (created == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inventory item added')));
      }
    } finally {
      for (final controller in [
        nameController,
        skuController,
        quantityController,
        minimumController,
        costController,
        supplierController,
        locationController,
        barcodeController,
        notesController,
      ]) {
        controller.dispose();
      }
    }
  }

  String? _validateNumber(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter a valid amount.' : null;
  }

  String? _optionalValue(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
