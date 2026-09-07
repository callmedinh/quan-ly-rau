import '../services/supabase_service.dart';
import 'errors.dart';
import 'local_store.dart';
import 'models.dart';

/// Suppliers data access: online-first with local-cache fallback.
class SupplierRepository {
  SupplierRepository(this._store);

  final LocalStore _store;

  /// List every supplier, sorted by name.
  /// Returns the cached list when offline (if a cache exists).
  Future<List<Supplier>> list() async {
    try {
      final rows =
          await SupabaseService.client.from('suppliers').select().order('name');
      final list = (rows as List)
          .map((e) => Supplier.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
      await _store.saveSuppliers(list);
      return list;
    } catch (_) {
      final cached = await _store.loadSuppliers();
      if (cached.isNotEmpty) return cached;
      throw const OfflineException(
          'Mất kết nối mạng và chưa có danh sách nhà cung cấp lưu sẵn.');
    }
  }

  /// Finds an existing supplier by phone/name, otherwise creates it.
  /// Used when importing a contact from the phone book or typing one.
  Future<Supplier> ensure({
    required String name,
    String? phone,
    String? address,
  }) async {
    final suppliers = await list(); // online or cached
    final trimmedName = name.trim();
    final normPhone = normalizePhone(phone);

    for (final s in suppliers) {
      if (trimmedName.isNotEmpty &&
          s.name.trim().toLowerCase() == trimmedName.toLowerCase()) {
        return s;
      }
      if (normPhone.isNotEmpty &&
          normalizePhone(s.phone).isNotEmpty &&
          normalizePhone(s.phone) == normPhone) {
        return s;
      }
    }

    return _insert(suppliers, name, phone, address);
  }

  /// Creates a brand-new supplier without duplicate checks (rare path).
  Future<Supplier> insertRaw({
    required String name,
    String? phone,
    String? address,
  }) async {
    return _insert(await _store.loadSuppliers(), name, phone, address);
  }

  Future<Supplier> _insert(
    List<Supplier> current,
    String name,
    String? phone,
    String? address,
  ) async {
    try {
      final row = await SupabaseService.client
          .from('suppliers')
          .insert({
            'name': name.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone,
            if (address != null && address.trim().isNotEmpty)
              'address': address,
          })
          .select()
          .single();
      final created = Supplier.fromMap((row as Map).cast<String, dynamic>());
      await _store.saveSuppliers([...current, created]);
      return created;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}

/// "0 912 345 678" / "+84 912345678" / "0912345678" -> "0912345678"
String normalizePhone(String? raw) {
  if (raw == null) return '';
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('84') && digits.length > 9) {
    digits = '0${digits.substring(2)}';
  }
  return digits;
}
