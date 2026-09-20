import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';
import 'settle_sheet.dart';

/// SCREEN 2 — "Chốt Giá" (evening price settlement at home).
///
/// Shows every batch that was imported but not yet priced
/// (is_price_settled = FALSE). Tapping one opens the calculator:
///   Suggested unit price = (Total revenue − Desired profit) / Quantity
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late AppServices _services;

  bool _loading = true;
  String? _error;
  List<PurchaseOrder> _pending = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.read<AppServices>();
    _load(); // runs once (didChangeDependencies fires again only on dep change)
  }

  Future<void> _load() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _services.purchases.pending();
      if (!mounted) return;
      setState(() {
        _pending = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openSettle(PurchaseOrder order) async {
    final settled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleSheet(order: order),
    );
    if (settled == true) {
      _toast('✅ Đã chốt giá xong phiếu này. Nợ đã cập nhật vào "Sổ Nợ".');
      _load();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chốt Giá'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            iconSize: 30,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: 'Đang tìm phiếu chờ chốt…');
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error!, onRetry: _load),
          Text(
            'Khi chưa có mạng, màn hình này dùng danh sách phiếu đã lưu gần nhất.',
            style: AppStyles.hint,
          ),
        ],
      );
    }
    if (_pending.isEmpty) {
      return const EmptyHint(
        icon: Icons.celebration,
        title: 'Hôm nay không còn phiếu nào chờ chốt!',
        message:
            'Phiếu nhập buổi sáng sẽ hiện ra đây để buổi tối chốt giá\n'
            'với nhà cung cấp.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            '📌 ${_pending.length} phiếu đang chờ chốt giá',
            style: AppStyles.bodyStrong,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            itemCount: _pending.length,
            itemBuilder: (context, i) {
              final order = _pending[i];
              return _PendingOrderCard(
                order: order,
                onTap: () => _openSettle(order),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  const _PendingOrderCard({required this.order, required this.onTap});

  final PurchaseOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final supplierInitial = (order.supplierName ?? '').isEmpty
        ? '?'
        : order.supplierName![0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    supplierInitial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.supplierLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        '${order.productLabel} — '
                        '${quantityLabel(order.quantity, order.productUnit)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.body.copyWith(fontSize: 18),
                      ),
                      if (order.notes != null && order.notes!.isNotEmpty)
                        Text('📝 ${order.notes}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.hint),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(shortDate(order.importDate),
                        style: AppStyles.hint),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Chờ giá',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
