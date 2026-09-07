import '../core/format.dart';
import '../services/supabase_service.dart';
import 'local_store.dart';
import 'models.dart';
import 'products_repo.dart';
import 'purchases_repo.dart';
import 'suppliers_repo.dart';

/// Report of one background sync pass.
class SyncReport {
  const SyncReport({
    required this.synced,
    required this.failedLabels,
    required this.stillQueued,
  });

  final int synced;
  final List<String> failedLabels;
  final int stillQueued;

  bool get hasWorkLeft => stillQueued > 0;
}

/// Pushes locally-queued fast imports (made while offline) to Supabase.
/// Runs on app start, on connectivity restore and after each successful save.
class SyncService {
  SyncService({
    required LocalStore store,
    required SupplierRepository suppliers,
    required ProductRepository products,
  })  : _store = store,
        _suppliers = suppliers,
        _products = products;

  final LocalStore _store;
  final SupplierRepository _suppliers;
  final ProductRepository _products;

  Future<SyncReport> syncNow() async {
    final queue = await _store.loadQueue();
    if (queue.isEmpty) {
      return const SyncReport(synced: 0, failedLabels: [], stillQueued: 0);
    }

    var synced = 0;
    final failed = <String>[];
    final remaining = [...queue];

    for (final item in remaining) {
      try {
        final supplier = await _resolveSupplier(item.supplier);
        final product = await _resolveProduct(item.product);

        await SupabaseService.client.from('purchase_orders').insert({
          'supplier_id': supplier.id,
          'product_id': product.id,
          'quantity': item.quantity,
          'import_date': sqlDate(item.importDate),
          'is_price_settled': false,
          if (item.notes != null && item.notes!.trim().isNotEmpty)
            'notes': item.notes,
        });

        await _store.removeFromQueue(item);
        synced++;
      } catch (e) {
        if (looksOffline(e)) {
          // Network dropped again mid-sync — stop, keep the rest queued.
          break;
        }
        failed.add(item.shortLabel);
        await _store.removeFromQueue(item); // not retryable, drop to avoid loop
      }
    }

    if (synced > 0) await _store.markSynced();
    final stillQueued = (await _store.loadQueue()).length;
    return SyncReport(synced: synced, failedLabels: failed, stillQueued: stillQueued);
  }

  Future<Supplier> _resolveSupplier(OfflineSupplierSnapshot snap) async {
    // If we know a real server id and it still exists, reuse it.
    if (snap.id != null) {
      final row = await SupabaseService.client
          .from('suppliers')
          .select('id')
          .eq('id', snap.id!)
          .maybeSingle();
      if (row != null) return Supplier(id: snap.id!, name: snap.name);
    }
    return _suppliers.ensure(name: snap.name, phone: snap.phone);
  }

  Future<Product> _resolveProduct(OfflineProductSnapshot snap) async {
    if (snap.id != null) {
      final row = await SupabaseService.client
          .from('products')
          .select('id')
          .eq('id', snap.id!)
          .maybeSingle();
      if (row != null) return Product(id: snap.id!, name: snap.name, unit: snap.unit);
    }
    return _products.ensure(name: snap.name, unit: snap.unit);
  }
}
