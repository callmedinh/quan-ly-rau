import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

/// Bottom sheet shown when the user taps a pending batch in the evening.
///
/// Smart anchor calculator:
///   Suggested unit price = (Total revenue − Desired profit) ÷ Quantity
/// The vendor calls the supplier, negotiates around this number, then
/// types the agreed `final_cost` and confirms — the order is settled and
/// the supplier's debt is updated (derived from settled orders − payments).
class SettleSheet extends StatefulWidget {
  const SettleSheet({super.key, required this.order});

  final PurchaseOrder order;

  @override
  State<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<SettleSheet> {
  final _totalCtrl = TextEditingController();
  final _desiredCtrl = TextEditingController();
  final _finalCtrl = TextEditingController();

  String? _errorText;
  bool _saving = false;

  double get _total =>
      parseMoneyOnlyDigits(_totalCtrl.text).toDouble();
  double get _desired =>
      parseMoneyOnlyDigits(_desiredCtrl.text).toDouble();
  double get _finalCost =>
      parseMoneyOnlyDigits(_finalCtrl.text).toDouble();

  /// (Tổng thu − lợi nhuận mong muốn) / số lượng
  double? get _suggestedUnitPrice {
    if (_total <= 0) return null;
    if (_desired > _total) return null;
    final qty = widget.order.quantity;
    if (qty <= 0) return null;
    final raw = (_total - _desired) / qty;
    return raw < 0 ? null : raw;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_totalCtrl, _desiredCtrl, _finalCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _desiredCtrl.dispose();
    _finalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errorText = null;
    });
    if (_total <= 0) {
      setState(() => _errorText = 'Chưa nhập tổng tiền thu được (mục 1).');
      return;
    }
    if (_finalCost <= 0) {
      setState(() => _errorText = 'Chưa nhập giá đã chốt với nhà cung cấp (mục 3).');
      return;
    }
    setState(() => _saving = true);
    try {
      final services = context.read<AppServices>();
      await services.purchases.settle(
        orderId: widget.order.id,
        finalCost: _finalCost,
        totalSalesAmount: _total,
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
    final order = widget.order;
    final suggested = _suggestedUnitPrice;
    final roundedSuggested =
        suggested == null ? null : (suggested / 100).round() * 100;
    final actualProfit = _total - order.quantity * _finalCost;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                children: [
                  // ── header ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chốt giá: ${order.supplierLabel}',
                                style: AppStyles.sectionTitle),
                            const SizedBox(height: 2),
                            Text(
                              '${order.productLabel} — '
                              '${quantityLabel(order.quantity, order.productUnit)}'
                              ' · ${shortDate(order.importDate)}',
                              style: AppStyles.body,
                            ),
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

                  // ── 1. total revenue ────────────────────────────────
                  Text('1️⃣ Tổng tiền bán được của lô hàng (đếm tiền sau khi bán):',
                      style: AppStyles.bodyStrong),
                  const SizedBox(height: 8),
                  _MoneyField(
                    controller: _totalCtrl,
                    hint: 'Ví dụ: 500000',
                  ),
                  const SizedBox(height: 14),

                  // ── 2. desired profit ───────────────────────────────
                  Text('2️⃣ Số lời bạn muốn kiếm ở lô này:',
                      style: AppStyles.bodyStrong),
                  const SizedBox(height: 8),
                  _MoneyField(controller: _desiredCtrl, hint: 'Ví dụ: 80000'),
                  const SizedBox(height: 14),

                  // ── anchor calculator ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.info, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 GIÁ ĐỀ XUẤT để gọi chốt với nhà cung cấp:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.info,
                            )),
                        const SizedBox(height: 6),
                        if (roundedSuggested == null)
                          const Text(
                            '(Tổng thu − lời mong muốn) ÷ số lượng\n→ điền mục 1 và 2 để xem giá đề xuất',
                            style: TextStyle(fontSize: 17, height: 1.4),
                          )
                        else ...[
                          Text(
                            money(roundedSuggested.toDouble()),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            'cho mỗi ${order.productUnit}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 3. final cost ───────────────────────────────────
                  Text('3️⃣ Giá nhập ĐÃ CHỐT với nhà cung cấp (mỗi ${order.productUnit}):',
                      style: AppStyles.bodyStrong),
                  const SizedBox(height: 8),
                  _MoneyField(controller: _finalCtrl, hint: 'Ví dụ: 4200'),
                  if (_finalCost > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tiền vốn lô này:',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            money(order.quantity * _finalCost),
                            style: AppStyles.amountSmall
                                .copyWith(color: AppColors.accentDark),
                          ),
                        ],
                      ),
                    ),
                  if (suggested != null &&
                      _finalCost > 0 &&
                      _finalCost > roundedSuggested! * 0.4)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '⚠️ Giá chốt cao hơn hẳn giá đề xuất — kiểm tra lại kẻo lỗ nhé!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lãi thực tế dự kiến:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(
                        money(actualProfit),
                        style: AppStyles.amountSmall.copyWith(
                          color: actualProfit >= 0
                              ? AppColors.primary
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ $_errorText',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Sau khi chốt, số nợ của nhà cung cấp tự cập nhật trong màn "Sổ Nợ".',
                    style: AppStyles.hint,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: BigButton(
                        label: 'Huỷ',
                        height: 62,
                        color: Colors.white,
                        foregroundColor: AppColors.inkSoft,
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BigButton(
                        label: '✅ Chốt Giá & Lưu',
                        height: 62,
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big money input: digits only, live ₫ formatting underneath.
class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 20, color: AppColors.inkSoft),
        suffixText: '₫',
        suffixStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary),
        helperText: controller.text.isEmpty
            ? null
            : '= ${moneyGrouped(parseMoneyOnlyDigits(controller.text))} đ',
        helperStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft),
      ),
    );
  }
}
