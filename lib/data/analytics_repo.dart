import 'models.dart';
import 'purchases_repo.dart';

/// Dashboard numbers computed from settled purchase orders.
class AnalyticsRepository {
  AnalyticsRepository(this._purchases);

  final PurchaseRepository _purchases;

  Future<DashboardSummary> compute({
    required DateTime from,
    required DateTime to,
  }) async {
    final settled = await _purchases.settledBetween(from, to);

    double revenue = 0, cost = 0;
    final byProduct = <String, _Acc>{};

    for (final o in settled) {
      final rev = o.totalSalesAmount ?? 0;
      final cst = o.totalCostValue;
      revenue += rev;
      cost += cst;

      final key = '${o.productName ?? o.productId}|${o.productUnit}';
      final acc = byProduct.putIfAbsent(
          key, () => _Acc(name: o.productName ?? 'Mặt hàng', unit: o.productUnit));
      acc.quantity += o.quantity;
      acc.revenue += rev;
      acc.cost += cst;
    }

    final top = byProduct.values
        .map((a) => ProductProfit(
            name: a.name, unit: a.unit, quantity: a.quantity,
            revenue: a.revenue, cost: a.cost))
        .toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));

    final pending = await _purchases.pendingCount();

    return DashboardSummary(
      revenue: revenue,
      totalCost: cost,
      netProfit: revenue - cost,
      orderCount: settled.length,
      pendingCount: pending,
      topProducts: top.take(6).toList(),
    );
  }
}

class _Acc {
  _Acc({required this.name, required this.unit});

  final String name;
  final String unit;
  double quantity = 0;
  double revenue = 0;
  double cost = 0;
}
