import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/purchases_repo.dart';
import '../../services/app_services.dart';
import '../shared/contact_selector.dart';
import 'product_picker_screen.dart';
import 'supplier_picker_screen.dart';

/// SCREEN 1 — "Nhập Hàng" (morning fast entry at the market).
///
/// 3 big steps, NO price required:
///   1️⃣ Pick supplier (phone book / saved list)
///   2️⃣ Pick product
///   3️⃣ Type quantity        →  is_price_settled = FALSE
class QuickImportScreen extends StatefulWidget {
  const QuickImportScreen({super.key});

  @override
  State<QuickImportScreen> createState() => _QuickImportScreenState();
}

class _QuickImportScreenState extends State<QuickImportScreen> {
  late AppServices _services;

  Supplier? _supplier;
  Product? _product;
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  List<PurchaseOrder> _today = const [];
  bool _todayLoading = true;
  String? _todayError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.read<AppServices>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadToday();
      _syncLeftovers();
    });
  }

  Future<void> _syncLeftovers() async {
    final leftovers = await _services.store.loadQueue();
    if (leftovers.isEmpty) return;
    final report = await _services.syncService.syncNow();
    if (!mounted || report.synced == 0) return;
    _toast('✅ Đã gửi ${report.synced} phiếu nhập còn chờ từ lúc mất mạng.');
  }

  Future<void> _loadToday() async {
    setState(() {
      _todayLoading = true;
      _todayError = null;
    });
    try {
      final orders = await _services.purchases.forDate(DateTime.now());
      if (!mounted) return;
      setState(() {
        _today = orders;
        _todayLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _todayError = friendlyError(e);
        _todayLoading = false;
      });
    }
  }

  // ───────────────────────────── actions ────────────────────────────────

  Future<void> _pickSupplierFromList() async {
    final picked =
        await Navigator.push<Supplier>(context,
            MaterialPageRoute(builder: (_) => const SupplierPickerScreen()));
    if (picked != null && mounted) setState(() => _supplier = picked);
  }

  Future<void> _pickSupplierFromContacts() async {
    final picked = await pickSupplierFromContacts(context);
    if (picked != null && mounted) setState(() => _supplier = picked);
  }

  Future<void> _pickProduct() async {
    final picked =
        await Navigator.push<Product>(context,
            MaterialPageRoute(builder: (_) => const ProductPickerScreen()));
    if (picked != null && mounted) setState(() => _product = picked);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final qty = parseQuantity(_qtyController.text);
    if (_supplier == null) {
      _toast('⚠️ Bước 1: chọn nhà cung cấp trước nhé!');
      return;
    }
    if (_product == null) {
      _toast('⚠️ Bước 2: chọn mặt hàng trước nhé!');
      return;
    }
    if (qty == null || qty <= 0) {
      _toast('⚠️ Bước 3: nhập số lượng (ví dụ: 5 hoặc 2.5).');
      return;
    }

    setState(() => _saving = true);
    try {
      final outcome = await _services.purchases.quickImport(
        supplier: _supplier!,
        product: _product!,
        quantity: qty,
        importDate: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (outcome == SaveOutcome.saved) {
        _toast('✅ Đã lưu: ${_supplier!.name} — ${_product!.name} '
            '${quantityLabel(qty, _product!.unit)}');
        _syncLeftovers(); // also flush any earlier offline entries
      } else {
        _toast('📥 Đang mất mạng — đã giữ phiếu này trên máy.\n'
            'Sẽ tự gửi lên khi có mạng lại.');
      }

      if (!mounted) return;
      setState(() => _saving = false);
      _qtyController.clear();
      _notesController.clear();
      _loadToday();
      FocusScope.of(context).requestFocus(_qtyFocusNode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(friendlyError(e));
    }
  }

  final _qtyFocusNode = FocusNode();

  void _adjustQuantity(double delta) {
    final current = parseQuantity(_qtyController.text) ?? 0;
    final next = (current + delta).clamp(0, 9999).toDouble();
    _qtyController.text = next == next.roundToDouble()
        ? next.round().toString()
        : next.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────── UI ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhập Hàng'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            iconSize: 30,
            onPressed: _loadToday,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                Text(
                  '${weekdayLabel(DateTime.now())} — ghi nhanh buổi sáng, '
                  'giá sẽ chốt buổi tối.',
                  style: AppStyles.body,
                ),
                const SizedBox(height: 14),
                _StepCard(
                  emoji: '1️⃣',
                  title: 'Chọn nhà cung cấp',
                  child: _supplier == null
                      ? Column(
                          children: [
                            BigButton(
                              label: '📱 Chọn Từ Danh Bạ',
                              icon: Icons.contact_phone,
                              color: AppColors.accent,
                              onPressed: _pickSupplierFromContacts,
                            ),
                            const SizedBox(height: 10),
                            BigButton(
                              label: '🗂️ Danh sách / Thêm nhà cung cấp',
                              icon: Icons.groups,
                              color: Colors.white,
                              foregroundColor: AppColors.primaryDark,
                              onPressed: _pickSupplierFromList,
                            ),
                          ],
                        )
                      : _PickedSupplierTile(
                          supplier: _supplier!,
                          onChange: _pickSupplierFromList,
                        ),
                ),
                const SizedBox(height: 12),
                _StepCard(
                  emoji: '2️⃣',
                  title: 'Chọn mặt hàng',
                  child: _product == null
                      ? BigButton(
                          label: '🥬 Chọn mặt hàng',
                          icon: Icons.eco,
                          onPressed: _pickProduct,
                        )
                      : _PickedProductTile(
                          product: _product!,
                          onChange: _pickProduct,
                        ),
                ),
                const SizedBox(height: 12),
                _StepCard(
                  emoji: '3️⃣',
                  title: 'Nhập số lượng',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _RoundIconButton(
                            icon: Icons.remove,
                            onTap: () => _adjustQuantity(-1),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: TextField(
                                controller: _qtyController,
                                focusNode: _qtyFocusNode,
                                textAlign: TextAlign.center,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]')),
                                ],
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: _product?.unit ?? '',
                                  suffixStyle: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _RoundIconButton(
                            icon: Icons.add,
                            onTap: () => _adjustQuantity(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final v in [5.0, 10.0, 20.0])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SelectableChip(
                                label: '${v.round()} ${_product?.unit ?? ''}',
                                selected: false,
                                onTap: () => _qtyController.text =
                                    v.round().toString(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: '📝 Ghi chú (không bắt buộc)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTodaySection(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: BigButton(
                label: '✅ Lưu Nhập Hàng',
                icon: Icons.check_circle,
                height: 72,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection() {
    return _StepCard(
      emoji: '📋',
      title: 'Hôm nay đã nhập (${_today.length})',
      child: _todayLoading
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: LoadingView(message: 'Đang xem lại…'))
          : _todayError != null
              ? Column(
                  children: [
                    Text(_todayError!,
                        style: AppStyles.body
                            .copyWith(color: AppColors.danger)),
                    TextButton.icon(
                      onPressed: _loadToday,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                  ],
                )
              : _today.isEmpty
                  ? const EmptyHint(
                      icon: Icons.inventory_2_outlined,
                      title: 'Chưa có phiếu nào hôm nay',
                      message: 'Điền 3 bước ở trên rồi bấm "Lưu Nhập Hàng".',
                    )
                  : Column(
                      children: [
                        for (final o in _today.take(40))
                          _TodayRow(order: o),
                      ],
                    ),
    );
  }
}

// ──────────────────────────── small widgets ─────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.emoji,
    required this.title,
    required this.child,
  });

  final String emoji;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE6DE)),
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
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppStyles.sectionTitle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PickedSupplierTile extends StatelessWidget {
  const _PickedSupplierTile({required this.supplier, required this.onChange});

  final Supplier supplier;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBg,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary,
              child: Text(
                supplier.name.isEmpty ? '?' : supplier.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.bodyStrong),
                  if (supplier.phone != null &&
                      supplier.phone!.trim().isNotEmpty)
                    Text(supplier.phone!, style: AppStyles.hint),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.swap_horiz, size: 24),
              label: const Text('Đổi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedProductTile extends StatelessWidget {
  const _PickedProductTile({required this.product, required this.onChange});

  final Product product;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBg,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Text('🥬', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.bodyStrong),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                product.unit,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.swap_horiz, size: 24),
              label: const Text('Đổi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              quantityLabel(order.quantity, order.productUnit),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.productLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text(order.supplierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.hint),
              ],
            ),
          ),
          Icon(
            order.isPriceSettled ? Icons.check_circle : Icons.schedule,
            color: order.isPriceSettled
                ? AppColors.primary
                : AppColors.gold,
            size: 26,
          ),
        ],
      ),
    );
  }
}
