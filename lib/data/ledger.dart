import 'models.dart';

/// One row of the SQL `supplier_balances()` aggregate.
class SupplierBalance {
  const SupplierBalance({
    required this.supplierId,
    required this.totalDue,
    required this.paidAmount,
    required this.orderCount,
    this.lastPaymentDate,
  });

  final String supplierId;
  final double totalDue;
  final double paidAmount;
  final int orderCount;
  final DateTime? lastPaymentDate;

  double get outstanding => totalDue - paidAmount;

  bool get hasActivity => orderCount > 0 || paidAmount > 0;

  factory SupplierBalance.fromRpc(Map<String, dynamic> m) => SupplierBalance(
        supplierId: m['supplier_id'] as String? ?? '',
        totalDue: (m['total_due'] as num?)?.toDouble() ?? 0,
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0,
        orderCount: (m['order_count'] as num?)?.toInt() ?? 0,
        lastPaymentDate: m['last_payment_date'] == null
            ? null
            : DateTime.tryParse(m['last_payment_date'].toString()),
      );
}

/// One supplier's row in the "Sổ Nợ" (debt ledger).
class SupplierDebt {
  const SupplierDebt({
    required this.supplierId,
    required this.name,
    this.phone,
    required this.totalDue,
    required this.paidTotal,
    required this.settledOrderCount,
    this.lastPaymentDate,
  });

  final String supplierId;
  final String name;
  final String? phone;

  /// Σ(quantity × final_cost) of settled orders.
  final double totalDue;

  /// Σ(payments.amount)
  final double paidTotal;
  final int settledOrderCount;
  final DateTime? lastPaymentDate;

  /// Money still owed to this supplier.
  double get outstanding => totalDue - paidTotal;

  bool get hasActivity => settledOrderCount > 0 || paidTotal > 0;
}

/// Builds the debt ledger by joining suppliers with their SQL aggregates.
///
/// Outstanding debt of a supplier =
///   Σ(quantity × final_cost of SETTLED orders) − Σ(payments made).
List<SupplierDebt> buildDebtLedger({
  required List<Supplier> suppliers,
  required List<SupplierBalance> balances,
}) {
  final byId = <String, SupplierBalance>{};
  for (final b in balances) {
    byId[b.supplierId] = b;
  }

  final result = <SupplierDebt>[];
  for (final s in suppliers) {
    final b = byId[s.id];
    if (b == null) continue; // no orders/payments → nothing to show
    result.add(SupplierDebt(
      supplierId: s.id,
      name: s.name,
      phone: s.phone,
      totalDue: b.totalDue,
      paidTotal: b.paidAmount,
      settledOrderCount: b.orderCount,
      lastPaymentDate: b.lastPaymentDate,
    ));
  }
  result.sort((a, b) => b.outstanding.compareTo(a.outstanding));
  return result;
}
