import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// Shown on first launch when Supabase credentials are still placeholders.
/// Explains (in Vietnamese) the 3 setup steps a developer must do.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.eco, size: 90, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text('Quản Lý Rau',
                textAlign: TextAlign.center, style: AppStyles.title),
            const SizedBox(height: 6),
            Text(
              'Ứng dụng cần kết nối Supabase trước khi dùng được.',
              textAlign: TextAlign.center,
              style: AppStyles.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            _StepBox(
              number: '1️⃣',
              title: 'Tạo project Supabase',
              body:
                  'Vào supabase.com → New project → nhớ lại Project URL và anon '
                  'public key (Settings → API).',
            ),
            _StepBox(
              number: '2️⃣',
              title: 'Chạy bảng dữ liệu (SQL)',
              body:
                  'Mở file supabase/migrations/0001_init.sql, dán toàn bộ vào '
                  'SQL Editor của Supabase rồi bấm Run.',
            ),
            _StepBox(
              number: '3️⃣',
              title: 'Điền khoá & chạy lại app',
              body:
                  'flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co '
                  '--dart-define=SUPABASE_ANON_KEY=eyJ...\n\n'
                  '(hoặc sửa trực tiếp trong lib/core/config.dart)',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3E3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: Text(
                'Hiện tại: URL = ${AppConfig.supabaseUrl}\n'
                'Anon key = ${_shorten(AppConfig.supabaseAnonKey)}',
                style: AppStyles.body.copyWith(fontSize: 17),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _shorten(String s) {
    if (s.length <= 24) return s;
    return '${s.substring(0, 20)}…';
  }
}

class _StepBox extends StatelessWidget {
  const _StepBox({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number $title', style: AppStyles.sectionTitle),
          const SizedBox(height: 8),
          Text(body,
              style: AppStyles.body.copyWith(
                  color: AppColors.inkSoft, fontSize: 17, height: 1.45)),
        ],
      ),
    );
  }
}
