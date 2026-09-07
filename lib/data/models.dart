/// Plain Dart data models mapped 1:1 to the Supabase tables.
/// Field names are camelCase in Dart, snake_case is converted in
/// fromMap / toMap.
library;

/// ────────────────────────────────────────────────────────────────────────
/// Small helpers to read PostgREST JSON values
/// ────────────────────────────────────────────────────────────────────────
double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(Object? value) => (value as num?)?.toInt() ?? 0;

DateTime? asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? asText(Object? value) =>
    value == null ? null : value.toString();

/// ────────────────────────────────────────────────────────────────────────
/// 1. Supplier — suppliers table
/// ────────────────────────────────────────────────────────────────────────
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final DateTime? createdAt;

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        phone: asText(m['phone']),
        address: asText(m['address']),
        createdAt: asDate(m['created_at']),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone,
        if (address != null && address!.trim().isNotEmpty) 'address': address,
      };
}

/// ────────────────────────────────────────────────────────────────────────
/// 2. Product — products table (unit: kg / bó / cân …)
/// ────────────────────────────────────────────────────────────────────────
class Product {
  const Product({
    required this.id,
    required this.name,
    this.unit = 'kg',
    this.createdAt,
  });

  final String id;
  final String name;
  final String unit;
  final DateTime? createdAt;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        unit: m['unit'] as String? ?? 'kg',
        createdAt: asDate(m['created_at']),
      );

  Map<String, dynamic> toInsertMap() => {'name': name, 'unit': unit};
}

/// ────────────────────────────────────────────────────────────────────────
/// 3. PurchaseOrder — purchase_orders table
///    (id, supplier_id, product_id, quantity, import_date,
///     is_price_settled, final_cost, total_sales_amount, notes)
/// ────────────────────────────────────────────────────────────────────────
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.productId,
    required this.quantity,
    required this.importDate,
    this.isPriceSettled = false,
    this.finalCost,
    this.totalSalesAmount,
    this.notes,
    this.createdAt,
    this.supplierName,
    this.supplierPhone,
    this.productName,
    this.productUnit = 'kg',
  });

  final String id;
  final String supplierId;
  final String productId;
  final double quantity;
  final DateTime importDate;
  final bool isPriceSettled;
  final double? finalCost;
  final double? totalSalesAmount;
  final String? notes;
  final DateTime? createdAt;

  /// Denormalised display fields (from PostgREST embedded relations).
  final String? supplierName;
  final String? supplierPhone;
  final String? productName;
  final String productUnit;

  String get supplierLabel => supplierName ?? supplierId.substring(0, 8);

  String get productLabel =>
      productName == null ? 'Mặt hàng #$productId' : productName!;

  double get totalCostValue => quantity * (finalCost ?? 0);

  double get profitValue =>
      (totalSalesAmount ?? 0) - totalCostValue;

  factory PurchaseOrder.fromRow(Map<String, dynamic> m) {
    final sup = m['suppliers'] is Map<String, dynamic>
        ? m['suppliers'] as Map<String, dynamic>
        : null;
    final prod = m['products'] is Map<String, dynamic>
        ? m['products'] as Map<String, dynamic>
        : null;
    return PurchaseOrder(
      id: m['id'] as String,
      supplierId: m['supplier_id'] as String? ?? '',
      productId: m['product_id'] as String? ?? '',
      quantity: asDouble(m['quantity']) ?? 0,
      importDate: asDate(m['import_date']) ?? DateTime.now(),
      isPriceSettled: m['is_price_settled'] == true,
      finalCost: asDouble(m['final_cost']),
      totalSalesAmount: asDouble(m['total_sales_amount']),
      notes: asText(m['notes']),
      createdAt: asDate(m['created_at']),
      supplierName: sup == null ? null : asText(sup['name']),
      supplierPhone: sup == null ? null : asText(sup['phone']),
      productName: prod == null ? null : asText(prod['name']),
      productUnit: prod == null ? 'kg' : (asText(prod['unit']) ?? 'kg'),
    );
  }

  /// Round-trip for the offline cache (keeps nested relations).
  Map<String, dynamic> toCacheRow() => {
        'id': id,
        'supplier_id': supplierId,
        'product_id': productId,
        'quantity': quantity,
        'import_date':
            '${importDate.year.toString().padLeft(4, '0')}-${importDate.month.toString().padLeft(2, '0')}-${importDate.day.toString().padLeft(2, '0')}',
        'is_price_settled': isPriceSettled,
        'final_cost': finalCost,
        'total_sales_amount': totalSalesAmount,
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
        'suppliers': (supplierName == null)
            ? null
            : {'name': supplierName, 'phone': supplierPhone},
        'products': (productName == null)
            ? null
            : {'name': productName, 'unit': productUnit},
      };
}

/// ────────────────────────────────────────────────────────────────────────
/// 4. Payment — payments table (money already paid back to a supplier)
/// ────────────────────────────────────────────────────────────────────────
class Payment {
  const Payment({
    required this.id,
    required this.supplierId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.supplierName,
  });

  final String id;
  final String supplierId;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final String? supplierName;

  factory Payment.fromRow(Map<String, dynamic> m) {
    final sup = m['suppliers'] is Map<String, dynamic>
        ? m['suppliers'] as Map<String, dynamic>
        : null;
    return Payment(
      id: m['id'] as String,
      supplierId: m['supplier_id'] as String? ?? '',
      amount: asDouble(m['amount']) ?? 0,
      paymentDate: asDate(m['payment_date']) ?? DateTime.now(),
      notes: asText(m['notes']),
      supplierName: sup == null ? null : asText(sup['name']),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Dashboard computations
/// ────────────────────────────────────────────────────────────────────────
class ProductProfit {
  const ProductProfit({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.revenue,
    required this.cost,
  });

  final String name;
  final String unit;
  final double quantity;
  final double revenue;
  final double cost;

  double get profit => revenue - cost;
}

class DashboardSummary {
  const DashboardSummary({
    required this.revenue,
    required this.totalCost,
    required this.netProfit,
    required this.orderCount,
    required this.pendingCount,
    required this.topProducts,
  });

  final double revenue;
  final double totalCost;
  final double netProfit;
  final int orderCount;
  final int pendingCount;
  final List<ProductProfit> topProducts;
}

/// ────────────────────────────────────────────────────────────────────────
/// 5. Offline queue item — a fast morning import stored locally when
///    there is no network. Synced later by SyncService.
/// ────────────────────────────────────────────────────────────────────────
class OfflineSupplierSnapshot {
  const OfflineSupplierSnapshot({this.id, required this.name, this.phone});

  final String? id;
  final String name;
  final String? phone;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'phone': phone};

  factory OfflineSupplierSnapshot.fromJson(Map<String, dynamic> m) =>
      OfflineSupplierSnapshot(
        id: asText(m['id']),
        name: m['name'] as String? ?? '',
        phone: asText(m['phone']),
      );
}

class OfflineProductSnapshot {
  const OfflineProductSnapshot({this.id, required this.name, this.unit = 'kg'});

  final String? id;
  final String name;
  final String unit;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'unit': unit};

  factory OfflineProductSnapshot.fromJson(Map<String, dynamic> m) =>
      OfflineProductSnapshot(
        id: asText(m['id']),
        name: m['name'] as String? ?? '',
        unit: asText(m['unit']) ?? 'kg',
      );
}

class QueuedPurchase {
  const QueuedPurchase({
    required this.supplier,
    required this.product,
    required this.quantity,
    required this.importDate,
    this.notes,
    this.queuedAt,
  });

  final OfflineSupplierSnapshot supplier;
  final OfflineProductSnapshot product;
  final double quantity;
  final DateTime importDate;
  final String? notes;
  final DateTime? queuedAt;

  Map<String, dynamic> toJson() => {
        'supplier': supplier.toJson(),
        'product': product.toJson(),
        'quantity': quantity,
        'import_date':
            '${importDate.year.toString().padLeft(4, '0')}-${importDate.month.toString().padLeft(2, '0')}-${importDate.day.toString().padLeft(2, '0')}',
        'notes': notes,
        'queued_at': (queuedAt ?? DateTime.now()).toIso8601String(),
      };

  factory QueuedPurchase.fromJson(Map<String, dynamic> m) => QueuedPurchase(
        supplier: OfflineSupplierSnapshot.fromJson(
            (m['supplier'] as Map?)?.cast<String, dynamic>() ?? {}),
        product: OfflineProductSnapshot.fromJson(
            (m['product'] as Map?)?.cast<String, dynamic>() ?? {}),
        quantity: asDouble(m['quantity']) ?? 0,
        importDate: asDate(m['import_date']) ?? DateTime.now(),
        notes: asText(m['notes']),
        queuedAt: asDate(m['queued_at']),
      );

  String get shortLabel =>
      '${supplier.name} — ${product.name} ${quantityLabelLocal()}';

  String quantityLabelLocal() {
    final q = quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toString();
    return '$q ${product.unit}';
  }
}
