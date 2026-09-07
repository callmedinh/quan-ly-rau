import '../services/supabase_service.dart';
import 'errors.dart';
import 'models.dart';

/// Payments (money paid back to suppliers) data access.
class PaymentRepository {
  const PaymentRepository();

  /// Records that [amount] was paid to the supplier (cash handed over).
  Future<void> pay({
    required String supplierId,
    required double amount,
    String? notes,
  }) async {
    try {
      await SupabaseService.client.from('payments').insert({
        'supplier_id': supplierId,
        'amount': amount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Most recent payments (with supplier names), for the history list.
  Future<List<Payment>> recent({int limit = 50}) async {
    try {
      final rows = await SupabaseService.client
          .from('payments')
          .select('*, suppliers(id,name)')
          .order('payment_date', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((e) => Payment.fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}
