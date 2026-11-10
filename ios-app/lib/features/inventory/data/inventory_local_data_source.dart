import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:proj/features/inventory/domain/entities/inventory_alert.dart';
import 'package:proj/features/inventory/domain/entities/inventory_item.dart';
import 'package:proj/features/inventory/domain/entities/stock_movement.dart';
import 'package:proj/features/inventory/domain/entities/supplier.dart';

/// Local storage for inventory data
class InventoryLocalDataSource {
  InventoryLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _itemsKey = 'inventory_items';
  static const _suppliersKey = 'inventory_suppliers';
  static const _movementsKey = 'inventory_movements';
  static const _alertsKey = 'inventory_alerts';

  // Inventory Items
  Future<List<InventoryItem>> readItems() async {
    try {
      final json = await _storage.read(key: _itemsKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveItems(List<InventoryItem> items) async {
    try {
      final json = jsonEncode(items.map((item) => item.toJson()).toList());
      await _storage.write(key: _itemsKey, value: json);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> saveItem(InventoryItem item) async {
    try {
      final items = await readItems();
      final index = items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        items[index] = item;
      } else {
        items.add(item);
      }
      await saveItems(items);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      final items = await readItems();
      items.removeWhere((item) => item.id == itemId);
      await saveItems(items);
    } catch (_) {
      // Handle error silently
    }
  }

  // Suppliers
  Future<List<Supplier>> readSuppliers() async {
    try {
      final json = await _storage.read(key: _suppliersKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map(
            (supplier) => Supplier.fromJson(supplier as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSuppliers(List<Supplier> suppliers) async {
    try {
      final json = jsonEncode(
        suppliers.map((supplier) => supplier.toJson()).toList(),
      );
      await _storage.write(key: _suppliersKey, value: json);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> saveSupplier(Supplier supplier) async {
    try {
      final suppliers = await readSuppliers();
      final index = suppliers.indexWhere((s) => s.id == supplier.id);
      if (index >= 0) {
        suppliers[index] = supplier;
      } else {
        suppliers.add(supplier);
      }
      await saveSuppliers(suppliers);
    } catch (_) {
      // Handle error silently
    }
  }

  // Stock Movements
  Future<List<StockMovement>> readMovements() async {
    try {
      final json = await _storage.read(key: _movementsKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map(
            (movement) =>
                StockMovement.fromJson(movement as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMovements(List<StockMovement> movements) async {
    try {
      final json = jsonEncode(movements.map((m) => m.toJson()).toList());
      await _storage.write(key: _movementsKey, value: json);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> recordMovement(StockMovement movement) async {
    try {
      final movements = await readMovements();
      movements.add(movement);
      await saveMovements(movements);
    } catch (_) {
      // Handle error silently
    }
  }

  // Inventory Alerts
  Future<List<InventoryAlert>> readAlerts() async {
    try {
      final json = await _storage.read(key: _alertsKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map(
            (alert) => InventoryAlert.fromJson(alert as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlerts(List<InventoryAlert> alerts) async {
    try {
      final json = jsonEncode(alerts.map((alert) => alert.toJson()).toList());
      await _storage.write(key: _alertsKey, value: json);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> saveAlert(InventoryAlert alert) async {
    try {
      final alerts = await readAlerts();
      final index = alerts.indexWhere((a) => a.id == alert.id);
      if (index >= 0) {
        alerts[index] = alert;
      } else {
        alerts.add(alert);
      }
      await saveAlerts(alerts);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> resolveAlert(String alertId) async {
    try {
      final alerts = await readAlerts();
      final index = alerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        alerts[index] = alerts[index].copyWith(
          isResolved: true,
          resolvedAt: DateTime.now(),
        );
        await saveAlerts(alerts);
      }
    } catch (_) {
      // Handle error silently
    }
  }
}
