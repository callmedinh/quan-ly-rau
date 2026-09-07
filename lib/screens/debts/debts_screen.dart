import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

/// SCREEN 3 — "Sổ Nợ" (debt ledger).
///
/// Shows each supplier's outstanding debt:
///   debt = Σ(settled batch value) − Σ(money paid back)
/// with a big "💵 Trả Tiền" button that logs cash into `payments`.
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late AppServices _services;

  bool _loading = true;
  String? _error;
  List<SupplierDebt> _ledger = const [];
  List<Payment> _recentPayments = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.read<AppServices>();
    _load();
  }

  Future<void> _load() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _services.suppliers.list(),
        _services.purchases.supplierBalances(),
        _services.payments.recent(limit: 50),
      ]);
      final suppliers = results[0] as List<Supplier>;
      final balances = results[1] as List<SupplierBalance>;
      final payments = results[2] as List<Payment>;

      final ledger = buildDebtLedger(
        suppliers: suppliers,
        balances: balances,
      );

      if (!mounted) return;
      setState(() {
        _ledger = ledger;
        _recentPayments = payments.take(10).toList();
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

  Future<void> _openPaySheet(SupplierDebt debt) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaySheet(debt: debt),
    );
    if (paid == true) {
      _toast('✅ Đã ghi nhận khoản trả nợ.');
      _load();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  double get _totalOutstanding {
    var total = 0.0;
    for (final d in _ledger) {
      total += d.outstanding;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sổ Nợ'),
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
    if (_loading) return const LoadingView(message: 'Đang tính nợ nhà cung cấp…');
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error!, onRetry: _load),
          Text(
            'Cần có mạng để tính sổ nợ chính xác (dữ liệu nằm trên máy chủ).',
            style: AppStyles.hint,
          ),
        ],
      );
    }
    final active = _ledger.where((d) => d.hasActivity).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      children: [
        // ── headline ──────────────────────────────────────────────────
        KpiCard(
          label: 'Tổng nợ đang giữ với nhà cung cấp',
          value: money(_totalOutstanding),
          accent: AppColors.danger,
          valueColor: AppColors.danger,
          icon: Icons.error_outline,
        ),
        const SizedBox(height: 14),
        Text('Nhà cung cấp', style: AppStyles.sectionTitle),
        const SizedBox(height: 8),
        if (active.isEmpty)
          const EmptyHint(
            icon: Icons.check_circle_outline,
            title: 'Chưa có khoản nợ nào!',
            message:
                'Sau khi chốt giá buổi tối, nợ của nhà cung cấp sẽ hiện ở đây.',
          ),
        for (final debt in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SupplierDebtCard(
              debt: debt,
              onPay: () => _openPaySheet(debt),
            ),
          ),
        if (_recentPayments.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Lịch sử trả gần đây', style: AppStyles.sectionTitle),
          const SizedBox(height: 8),
          for (final p in _recentPayments)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.supplierName ?? 'Nhà cung cấp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(p.amount),
                          style: AppStyles.amountSmall
                              .copyWith(color: AppColors.primary)),
                      Text(
                        '${shortDate(p.paymentDate)} '
                        '${p.paymentDate.hour.toString().padLeft(2, '0')}:'
                        '${p.paymentDate.minute.toString().padLeft(2, '0')}',
                        style: AppStyles.hint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _SupplierDebtCard extends StatelessWidget {
  const _SupplierDebtCard({required this.debt, required this.onPay});

  final SupplierDebt debt;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final initial =
        debt.name.isEmpty ? '?' : debt.name[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
            color: debt.outstanding > 0
                ? AppColors.danger
                : AppColors.primary,
            width: 6,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: debt.outstanding > 0
                    ? AppColors.dangerBg
                    : AppColors.primaryBg,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: debt.outstanding > 0
                        ? AppColors.danger
                        : AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.bodyStrong),
                    if (debt.phone != null)
                      Text(debt.phone!, style: AppStyles.hint),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Còn nợ:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(
                money(debt.outstanding),
                style: AppStyles.amountSmall.copyWith(
                  color: debt.outstanding > 0
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          if (debt.paidTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đã trả: ${debt.settledOrderCount} lần',
                      style: AppStyles.hint),
                  Text('Đã trả ${money(debt.paidTotal)}',
                      style: AppStyles.hint),
                ],
              ),
            ),
          const SizedBox(height: 12),
          BigButton(
            label: '💵 Trả Tiền',
            height: 58,
            color: AppColors.primary,
            onPressed: debt.outstanding <= 0 ? null : onPay,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: log a cash payment to a supplier.
class PaySheet extends StatefulWidget {
  const PaySheet({super.key, required this.debt});

  final SupplierDebt debt;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _errorText;

  double get _amount =>
      parseMoneyOnlyDigits(_amountCtrl.text).toDouble();

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    _amountCtrl.text = v.round().toString();
  }

  Future<void> _save() async {
    setState(() => _errorText = null);
    if (_amount <= 0) {
      setState(() => _errorText = 'Nhập số tiền đã trả.');
      return;
    }
    setState(() => _saving = true);
    try {
      final services = context.read<AppServices>();
      await services.payments.pay(
        supplierId: widget.debt.supplierId,
        amount: _amount,
        notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💵 Trả tiền cho: ${debt.name}',
                            style: AppStyles.sectionTitle),
                        Text('Còn nợ ${money(debt.outstanding)}',
                            style: AppStyles.body.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 34,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: '100.000',
                    selected: _amount == 100000,
                    onTap: () => _setAmount(100000),
                  ),
                  SelectableChip(
                    label: '200.000',
                    selected: _amount == 200000,
                    onTap: () => _setAmount(200000),
                  ),
                  SelectableChip(
                    label: '500.000',
                    selected: _amount == 500000,
                    onTap: () => _setAmount(500000),
                  ),
                  SelectableChip(
                    label: '1.000.000',
                    selected: _amount == 1000000,
                    onTap: () => _setAmount(1000000),
                  ),
                  if (debt.outstanding > 0)
                    SelectableChip(
                      label: 'Trả hết ${moneyGrouped(debt.outstanding)}',
                      selected: _amount == debt.outstanding,
                      onTap: () => _setAmount(debt.outstanding),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'Nhập số tiền trả',
                  suffixText: '₫',
                  suffixStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '📝 Ghi chú (không bắt buộc)',
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('⚠️ $_errorText',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                ),
              const SizedBox(height: 16),
              BigButton(
                label: '✅ Xác nhận đã trả',
                height: 66,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
