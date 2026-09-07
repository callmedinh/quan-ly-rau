import '../services/supabase_service.dart';
import 'errors.dart';
import 'local_store.dart';
import 'models.dart';

/// Products (vegetables) data access: online-first with local-cache fallback.
class ProductRepository {
  ProductRepository(this._store);

  final LocalStore _store;

  Future<List<Product>> list() async {
    try {
      final rows =
          await SupabaseService.client.from('products').select().order('name');
      final list = (rows as List)
          .map((e) => Product.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
      await _store.saveProducts(list);
      return list;
    } catch (_) {
      final cached = await _store.loadProducts();
      if (cached.isNotEmpty) return cached;
      throw const OfflineException(
          'Mất kết nối mạng và chưa có danh sách mặt hàng lưu sẵn.');
    }
  }

  /// Returns an existing product with the same name or creates a new one.
  Future<Product> ensure({required String name, required String unit}) async {
    final products = await list();
    final trimmed = name.trim();
    for (final p in products) {
      if (p.name.trim().toLowerCase() == trimmed.toLowerCase()) return p;
    }
    try {
      final row = await SupabaseService.client
          .from('products')
          .insert({'name': trimmed, 'unit': unit})
          .select()
          .single();
      final created = Product.fromMap((row as Map).cast<String, dynamic>());
      await _store.saveProducts([...products, created]);
      return created;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}
