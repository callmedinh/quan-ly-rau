import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

const List<String> kProductUnits = ['kg', 'bó', 'cân', 'chục', 'lạng', 'thùng'];

/// Full-screen product picker. Pops with the selected [Product] or a
/// newly added one.
class ProductPickerScreen extends StatefulWidget {
  const ProductPickerScreen({super.key});

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  late final AppServices _services;

  bool _loading = true;
  String? _error;
  List<Product> _all = const [];
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.read<AppServices>();
    if (_all.isEmpty && _loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _services.products.list();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  List<Product> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((p) =>
            p.name.toLowerCase().contains(q) || p.unit.contains(q))
        .toList();
  }

  Future<void> _addNew() async {
    final created = await showDialog<Product>(
      context: context,
      builder: (_) => const _AddProductDialog(),
    );
    if (created != null && mounted) {
      // Add it to the local list, then return it as the chosen product.
      setState(() => _all = [..._all, created]);
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn mặt hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 30),
        label: const Text('Mặt hàng mới',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: '🔍 Tìm mặt hàng (rau, củ, quả…)',
                  prefixIcon: Icon(Icons.search, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView(message: 'Đang tải mặt hàng…');
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 8),
          Text(
            'Danh sách mặt hàng cũ được lưu trên máy vẫn dùng được khi mất mạng.',
            style: AppStyles.hint,
          ),
        ],
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return EmptyHint(
        icon: Icons.eco,
        title: _search.text.isEmpty ? 'Chưa có mặt hàng nào' : 'Không tìm thấy',
        message: _search.text.isEmpty
            ? 'Bấm nút "Mặt hàng mới" để thêm loại rau đầu tiên.'
            : 'Bấm "Mặt hàng mới" để thêm loại rau này.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final p = visible[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(context, p),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Text('🥬', style: TextStyle(fontSize: 34)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.bodyStrong),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        p.unit,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        size: 34, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modal: add a brand-new product (name + unit).
class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog();

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _name = TextEditingController();
  String _unit = 'kg';
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên mặt hàng.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final services = context.read<AppServices>();
      final created = await services.products
          .ensure(name: _name.text.trim(), unit: _unit);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('＋ Thêm mặt hàng',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                  labelText: 'Tên (ví dụ: Cải ngọt)',
                  labelStyle: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            const Text('Đơn vị tính:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in kProductUnits)
                  SelectableChip(
                    label: u,
                    selected: _unit == u,
                    onTap: () => setState(() => _unit = u),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(140, 54),
          ),
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
              : const Text('Lưu',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
