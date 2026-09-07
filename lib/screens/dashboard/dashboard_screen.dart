import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

/// SCREEN 4 — "Báo Cáo Lời Lỗ" (analytics dashboard).
///
/// Big, high-contrast cards:
///   • Tổng Thu (total revenue)      • Tổng Vốn (capital cost)
///   • Lợi Nhuận Ròng (net profit)
///   • Top loại rau lời nhất (most profitable products)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _Period { today, week, month }

class _DashboardScreenState extends State<DashboardScreen> {
  late AppServices _services;

  _Period _period = _Period.week;
  bool _loading = true;
  String? _error;
  DashboardSummary? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.read<AppServices>();
    _load();
  }

  (DateTime, DateTime) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.today:
        return (today, now);
      case _Period.week:
        return (today.subtract(const Duration(days: 6)), now);
      case _Period.month:
        return (today.subtract(const Duration(days: 29)), now);
    }
  }

  Future<void> _load() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final (from, to) = _range;
    try {
      final summary =
          await _services.analytics.compute(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _data = summary;
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

  void _switchPeriod(_Period p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo Cáo Lời Lỗ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            iconSize: 30,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                for (final p in _Period.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectableChip(
                      label: switch (p) {
                        _Period.today => 'Hôm nay',
                        _Period.week => '7 ngày',
                        _Period.month => '30 ngày',
                      },
                      selected: p == _period,
                      onTap: () => _switchPeriod(p),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: 'Đang tính báo cáo…');
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error!, onRetry: _load),
          Text(
            'Báo cáo chỉ tính các phiếu ĐÃ chốt giá (có đủ tiền thu + giá nhập).',
            style: AppStyles.hint,
          ),
        ],
      );
    }
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final (from, to) = _range;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Text(
          'Từ ${shortDate(from)} đến ${shortDate(to)} '
          '(${d.orderCount} phiếu đã chốt)',
          style: AppStyles.hint,
        ),
        const SizedBox(height: 10),
        // ── big numbers ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Tổng Thu',
                value: money(d.revenue),
                accent: AppColors.primary,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Tổng Vốn',
                value: money(d.totalCost),
                accent: AppColors.accentDark,
                valueColor: AppColors.accentDark,
                icon: Icons.shopping_basket,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        KpiCard(
          label: 'Lợi Nhuận Ròng',
          value: money(d.netProfit),
          accent: d.netProfit >= 0 ? AppColors.primary : AppColors.danger,
          valueColor: d.netProfit >= 0 ? AppColors.primary : AppColors.danger,
          icon: d.netProfit >= 0 ? Icons.sentiment_satisfied : Icons.error,
        ),
        const SizedBox(height: 12),
        if (d.pendingCount > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0x40E9C46A), // gold @ 25%
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.accentDark, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Còn ${d.pendingCount} phiếu chưa chốt giá buổi tối — '
                    'chuyển sang tab "Chốt Giá" nhé!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text('🥇 Top loại rau lời nhất', style: AppStyles.sectionTitle),
        const SizedBox(height: 8),
        if (d.topProducts.isEmpty)
          const EmptyHint(
            icon: Icons.eco,
            title: 'Chưa có dữ liệu lời lỗ',
            message:
                'Chốt giá xong các phiếu buổi tối, báo cáo sẽ hiện ra đây.',
          )
        else
          ..._buildTopProducts(d.topProducts),
      ],
    );
  }

  List<Widget> _buildTopProducts(List<ProductProfit> top) {
    final maxProfit = top
        .where((p) => p.profit > 0)
        .fold(0.0, (m, p) => p.profit > m ? p.profit : m);

    return [
      for (var i = 0; i < top.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RankBadge(rank: i + 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      top[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.bodyStrong,
                    ),
                  ),
                  Text(
                    money(top[i].profit),
                    style: AppStyles.amountSmall.copyWith(
                      color: top[i].profit >= 0
                          ? AppColors.primary
                          : AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: maxProfit <= 0 || top[i].profit <= 0
                      ? 0
                      : (top[i].profit / maxProfit).clamp(0.05, 1.0).toDouble(),
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE3EAE4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    top[i].profit >= 0
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bán ${quantityLabel(top[i].quantity, top[i].unit)} · '
                'thu ${money(top[i].revenue)} · vốn ${money(top[i].cost)}',
                style: AppStyles.hint,
              ),
            ],
          ),
        ),
    ];
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFF4B400), // 1st - gold
      Color(0xFF9AA5B1), // 2nd - silver
      Color(0xFFB06A3B), // 3rd - bronze
    ];
    final color = rank <= 3 ? colors[rank - 1] : AppColors.primaryLight;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
