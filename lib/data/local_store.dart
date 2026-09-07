import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Local persistence on the device (shared_preferences).
///
/// Two responsibilities:
///  1. Cache of master data (suppliers, products, pending orders) so the
///     app keeps working when the market has no signal.
///  2. Offline queue: fast morning imports written while offline, synced
///     to Supabase as soon as a connection is available.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const _kSuppliers = 'cache_suppliers_v1';
  static const _kProducts = 'cache_products_v1';
  static const _kPendingOrders = 'cache_pending_orders_v1';
  static const _kQueue = 'offline_queue_v1';
  static const _kLastSync = 'last_sync_at_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ───────────────────────────── Suppliers ─────────────────────────────
  Future<void> saveSuppliers(List<Supplier> list) async {
    final sp = await _sp;
    await sp.setString(
      _kSuppliers,
      jsonEncode(list.map((s) => s.toInsertMap()..['id'] = s.id).toList()),
    );
  }

  Future<List<Supplier>> loadSuppliers() async {
    final sp = await _sp;
    final raw = sp.getString(_kSuppliers);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final rows = jsonDecode(raw) as List;
      return rows
          .map((e) => Supplier.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ───────────────────────────── Products ──────────────────────────────
  Future<void> saveProducts(List<Product> list) async {
    final sp = await _sp;
    await sp.setString(
      _kProducts,
      jsonEncode(list.map((p) => p.toInsertMap()..['id'] = p.id).toList()),
    );
  }

  Future<List<Product>> loadProducts() async {
    final sp = await _sp;
    final raw = sp.getString(_kProducts);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final rows = jsonDecode(raw) as List;
      return rows
          .map((e) => Product.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ────────────────────────── Pending orders cache ─────────────────────
  Future<void> savePendingOrders(List<PurchaseOrder> list) async {
    final sp = await _sp;
    await sp.setString(
      _kPendingOrders,
      jsonEncode(list.map((o) => o.toCacheRow()).toList()),
    );
  }

  Future<List<PurchaseOrder>> loadPendingOrders() async {
    final sp = await _sp;
    final raw = sp.getString(_kPendingOrders);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final rows = jsonDecode(raw) as List;
      return rows
          .map((e) => PurchaseOrder.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ──────────────────────────── Offline queue ──────────────────────────
  Future<List<QueuedPurchase>> loadQueue() async {
    final sp = await _sp;
    final raw = sp.getString(_kQueue);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final rows = jsonDecode(raw) as List;
      return rows
          .map((e) => QueuedPurchase.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveQueue(List<QueuedPurchase> queue) async {
    final sp = await _sp;
    await sp.setString(
      _kQueue,
      jsonEncode(queue.map((q) => q.toJson()).toList()),
    );
  }

  Future<void> enqueue(QueuedPurchase item) async {
    final queue = await loadQueue();
    queue.add(item);
    await _saveQueue(queue);
  }

  Future<void> removeFromQueue(QueuedPurchase item) async {
    final queue = await loadQueue();
    queue.removeWhere((q) =>
        q.queuedAt == item.queuedAt &&
        q.supplier.name == item.supplier.name &&
        q.product.name == item.product.name);
    await _saveQueue(queue);
  }

  Future<void> clearQueue() async {
    final sp = await _sp;
    await sp.remove(_kQueue);
  }

  // ───────────────────────────── Misc ──────────────────────────────────
  Future<DateTime?> lastSyncAt() async {
    final sp = await _sp;
    final raw = sp.getString(_kLastSync);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markSynced() async {
    final sp = await _sp;
    await sp.setString(_kLastSync, DateTime.now().toIso8601String());
  }
}
