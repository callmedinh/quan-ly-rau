import '../core/format.dart';
import '../services/supabase_service.dart';
import 'errors.dart';
import 'ledger.dart';
import 'local_store.dart';
import 'models.dart';

/// Result of saving a quick morning import.
enum SaveOutcome {
  /// Written to Supabase immediately.
  saved,

  /// No network — stored on the phone, will sync later automatically.
  queuedOffline,
}

/// Purchase orders data access (the heart of the 2-phase workflow).
class PurchaseRepository {
  PurchaseRepository(this._store);

  final LocalStore _store;

  // ─────────────────────────── Phase 1: fast entry ─────────────────────
  /// Saves an import with NO price (is_price_settled = FALSE).
  /// Falls back to the offline queue when there is no network.
  Future<SaveOutcome> quickImport({
    required Supplier supplier,
    required Product product,
    required double quantity,
    required DateTime importDate,
    String? notes,
  }) async {
    final row = {
      'supplier_id': supplier.id,
      'product_id': product.id,
      'quantity': quantity,
      'import_date': sqlDate(importDate),
      'is_price_settled': false,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    try {
      await SupabaseService.client.from('purchase_orders').insert(row);
      return SaveOutcome.saved;
    } catch (e) {
      if (!looksOffline(e)) throw AppException(friendlyError(e));
      // Offline: keep the full snapshot locally and sync later.
      await _store.enqueue(QueuedPurchase(
        supplier: OfflineSupplierSnapshot(
            id: supplier.id, name: supplier.name, phone: supplier.phone),
        product: OfflineProductSnapshot(
            id: product.id, name: product.name, unit: product.unit),
        quantity: quantity,
        importDate: importDate,
        notes: notes,
      ));
      return SaveOutcome.queuedOffline;
    }
  }

  // ──────────────────── Phase 2: evening settlement ────────────────────
  /// Pending batches: is_price_settled = FALSE (need a deal price).
  Future<List<PurchaseOrder>> pending() async {
    try {
      final rows = await SupabaseService.client
          .from('purchase_orders')
          .select('*, suppliers(id,name,phone), products(id,name,unit)')
          .eq('is_price_settled', false)
          .order('import_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(1000);
      final list = (rows as List)
          .map((e) => PurchaseOrder.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
      await _store.savePendingOrders(list);
      return list;
    } catch (_) {
      final cached = await _store.loadPendingOrders();
      if (cached.isNotEmpty) return cached;
      throw const OfflineException(
          'Mất kết nối mạng và chưa có danh sách phiếu chờ chốt giá lưu sẵn.');
    }
  }

  /// Settles a batch: stores the agreed final unit price + total revenue.
  Future<void> settle({
    required String orderId,
    required double finalCost,
    required double totalSalesAmount,
  }) async {
    try {
      await SupabaseService.client
          .from('purchase_orders')
          .update({
            'final_cost': finalCost,
            'total_sales_amount': totalSalesAmount,
            'is_price_settled': true,
          })
          .eq('id', orderId);
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  // ───────────────────────────── Queries ───────────────────────────────
  Future<List<PurchaseOrder>> forDate(DateTime day) async {
    final dayStr = sqlDate(day);
    try {
      final rows = await SupabaseService.client
          .from('purchase_orders')
          .select('*, suppliers(id,name,phone), products(id,name,unit)')
          .eq('import_date', dayStr)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => PurchaseOrder.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Settled orders inside [from]..[to] (inclusive), newest first.
  Future<List<PurchaseOrder>> settledBetween(
      DateTime from, DateTime to) async {
    try {
      final rows = await SupabaseService.client
          .from('purchase_orders')
          .select('*, suppliers(id,name), products(id,name,unit)')
          .eq('is_price_settled', true)
          .gte('import_date', sqlDate(from))
          .lte('import_date', sqlDate(to))
          .order('import_date', ascending: true);
      return (rows as List)
          .map((e) => PurchaseOrder.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Every settled order (used to build the supplier debt ledger).
  Future<List<PurchaseOrder>> allSettled() async {
    try {
      final rows = await SupabaseService.client
          .from('purchase_orders')
          .select('id, supplier_id, quantity, final_cost, import_date')
          .eq('is_price_settled', true)
          .order('import_date', ascending: true);
      return (rows as List)
          .map((e) => PurchaseOrder.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Aggregate supplier balances straight from Postgres (safe for large
  /// ledgers — never truncated by the API row limit).
  Future<List<SupplierBalance>> supplierBalances() async {
    try {
      final rows = await SupabaseService.client.rpc('supplier_balances');
      return (rows as List)
          .map((e) => SupplierBalance.fromRpc((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Number of batches still waiting for a deal price.
  Future<int> pendingCount() async {
    try {
      final rows = await SupabaseService.client
          .from('purchase_orders')
          .select('id')
          .eq('is_price_settled', false);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}

/// True when an error is probably caused by a missing network.
bool looksOffline(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('connection') ||
      text.contains('timed out') ||
      text.contains('network') ||
      text.contains('handshake') ||
      text.contains('econn') ||
      text.contains('host lookup');
}
