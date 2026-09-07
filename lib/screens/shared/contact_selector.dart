import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';
import '../../services/contacts_service.dart';

/// Senior-friendly contact picker flow:
///  1. ask for READ_CONTACTS (or guide the user to Settings),
///  2. show a searchable, big-row list of phone contacts,
///  3. `ensure()` the chosen contact as a Supplier in Supabase.
///
/// Returns the Supplier when a contact was chosen & saved, else null.
Future<Supplier?> pickSupplierFromContacts(BuildContext context) async {
  final services = context.read<AppServices>();
  final messenger = ScaffoldMessenger.of(context);

  final granted = await services.contacts.ensurePermission();
  if (!granted) {
    final openSettings = await _showPermissionDialog(context);
    if (openSettings == true) await openAppSettings();
    return null;
  }

  final Contact? picked = await _showContactPickerSheet(context);
  if (picked == null || !context.mounted) return null;

  final name = ContactsService.displayName(picked);
  final phone = ContactsService.phoneOf(picked);

  try {
    return await services.suppliers.ensure(name: name, phone: phone);
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(friendlyError(e)),
    ));
    return null;
  }
}

Future<bool?> _showPermissionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cần quyền danh bạ 📱',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      content: const Text(
        'Để lấy tên và số điện thoại từ danh bạ, ứng dụng cần quyền '
        '"Danh bạ" của máy. Bấm "Mở Cài Đặt" rồi bật quyền Danh bạ cho app.',
        style: TextStyle(fontSize: 19, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Để sau',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(120, 52),
          ),
          child: const Text('Mở Cài Đặt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

Future<Contact?> _showContactPickerSheet(BuildContext context) {
  return showModalBottomSheet<Contact>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.92,
      child: _ContactPickerSheet(),
    ),
  );
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet();

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  late final Future<List<Contact>> _future;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().contacts.loadContacts();
  }

  List<Contact> _visible(List<Contact> source) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((c) {
      final name = ContactsService.displayName(c).toLowerCase();
      final phone = ContactsService.phoneOf(c)?.toLowerCase() ?? '';
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('📱 Chọn Từ Danh Bạ',
                      style: AppStyles.sectionTitle),
                ),
                IconButton(
                  iconSize: 34,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                hintText: '🔍 Tìm tên hoặc số điện thoại…',
                prefixIcon: Icon(Icons.search, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FutureBuilder<List<Contact>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Đang đọc danh bạ…');
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: AppColors.danger),
                          const SizedBox(height: 12),
                          const Text(
                            'Không đọc được danh bạ.\nVui lòng kiểm tra quyền truy cập.',
                            textAlign: TextAlign.center,
                            style: AppStyles.body,
                          ),
                          const SizedBox(height: 16),
                          BigButton(
                            label: 'Đóng',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snap.data ?? const [];
                final visible = _visible(data);
                if (visible.isEmpty) {
                  return const EmptyHint(
                    icon: Icons.contact_phone,
                    title: 'Không tìm thấy liên hệ',
                    message:
                        'Đổi từ khoá tìm kiếm, hoặc nhập nhà cung cấp bằng tay ở màn hình trước.',
                  );
                }
                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final c = visible[i];
                    final name = ContactsService.displayName(c);
                    final phone = ContactsService.phoneOf(c);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, c),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primaryBg,
                                  child: Text(
                                    name.isEmpty ? '?' : name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppStyles.bodyStrong),
                                      if (phone != null)
                                        Text(phone,
                                            style: AppStyles.hint),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    size: 32, color: AppColors.primaryLight),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
