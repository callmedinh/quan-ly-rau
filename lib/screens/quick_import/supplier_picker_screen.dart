import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';
import '../shared/contact_selector.dart';

/// Full-screen supplier picker.
/// Pops with the selected [Supplier] (or adds a new one from a contact /
/// typed manually).
class SupplierPickerScreen extends StatefulWidget {
  const SupplierPickerScreen({super.key});

  @override
  State<SupplierPickerScreen> createState() => _SupplierPickerScreenState();
}

class _SupplierPickerScreenState extends State<SupplierPickerScreen> {
  late final AppServices _services;

  bool _loading = true;
  String? _error;
  List<Supplier> _all = const [];
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
      final list = await _services.suppliers.list();
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

  List<Supplier> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.phone ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addManually() async {
    final created = await showDialog<Supplier>(
      context: context,
      builder: (_) => const _AddSupplierDialog(),
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }

  Future<void> _fromContacts() async {
    final supplier = await pickSupplierFromContacts(context);
    if (supplier != null && mounted) Navigator.pop(context, supplier);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn nhà cung cấp')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManually,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1, size: 28),
        label: const Text('Thêm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: BigButton(
                label: '📱 Chọn Từ Danh Bạ',
                icon: Icons.contact_phone,
                color: AppColors.accent,
                onPressed: _fromContacts,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: '🔍 Tìm theo tên hoặc số điện thoại…',
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
    if (_loading) return const LoadingView(message: 'Đang tải nhà cung cấp…');
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 8),
          Text(
            'Mẹo: nếu đang mất mạng, hãy bấm "📱 Chọn Từ Danh Bạ" — app sẽ thử lại '
            'khi có sóng, hoặc chọn lại sau khi máy có mạng.',
            style: AppStyles.hint,
          ),
        ],
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return const EmptyHint(
        icon: Icons.groups,
        title: 'Chưa có nhà cung cấp nào',
        message:
            'Bấm "📱 Chọn Từ Danh Bạ" để lấy từ danh bạ điện thoại,\n'
            'hoặc bấm nút "＋ Thêm" bên dưới góc phải.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final s = visible[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(context, s),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryBg,
                      child: Text(
                        s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
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
                          Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.bodyStrong),
                          if (s.phone != null && s.phone!.trim().isNotEmpty)
                            Text(s.phone!, style: AppStyles.hint),
                        ],
                      ),
                    ),
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

/// Modal: type a supplier manually.
class _AddSupplierDialog extends StatefulWidget {
  const _AddSupplierDialog();

  @override
  State<_AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<_AddSupplierDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng nhập tên nhà cung cấp.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final services = context.read<AppServices>();
      final created = await services.suppliers.ensure(
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address:
            _address.text.trim().isEmpty ? null : _address.text.trim(),
      );
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
      title: const Text('＋ Thêm nhà cung cấp',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                  labelText: 'Tên (ví dụ: Chú Tư)', labelStyle: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                  labelText: 'Số điện thoại (không bắt buộc)',
                  labelStyle: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                  labelText: 'Địa chỉ (không bắt buộc)',
                  labelStyle: TextStyle(fontSize: 18)),
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
