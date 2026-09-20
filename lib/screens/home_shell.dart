import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_services.dart';
import 'dashboard/dashboard_screen.dart';
import 'debts/debts_screen.dart';
import 'quick_import/quick_import_screen.dart';
import 'settlement/settlement_screen.dart';

/// Root scaffold with the 4 big bottom tabs:
///   1. Nhập Hàng (morning fast entry)
///   2. Chốt Giá  (evening settlement)
///   3. Sổ Nợ     (debt ledger)
///   4. Báo Cáo   (profit dashboard)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final offline =
        context.select((ValueNotifier<bool> n) => !n.value);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (offline) const OfflineBanner(),
            // Re-create the active tab on every switch so lists are always
            // freshly loaded (import → settle → debts → report workflow).
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('tab_$_index'),
                child: _buildTab(_index),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.store),
            selectedIcon: Icon(Icons.store, color: AppColors.primary),
            label: 'Nhập Hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.price_check),
            selectedIcon: Icon(Icons.price_check, color: AppColors.primary),
            label: 'Chốt Giá',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            selectedIcon: Icon(Icons.menu_book, color: AppColors.primary),
            label: 'Sổ Nợ',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights),
            selectedIcon: Icon(Icons.insights, color: AppColors.primary),
            label: 'Báo Cáo',
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const QuickImportScreen();
      case 1:
        return const SettlementScreen();
      case 2:
        return const DebtsScreen();
      default:
        return const DashboardScreen();
    }
  }
}

/// Thin green bar shown while the device has no network.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return Container(
      width: double.infinity,
      color: AppColors.accentDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Đang mất mạng — vẫn nhập được, sẽ tự đồng bộ sau',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final rep = await services.syncService.syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(rep.synced > 0
                      ? '✅ Đã đồng bộ ${rep.synced} phiếu nhập.'
                      : 'Chưa có phiếu chờ đồng bộ.'),
                ));
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black26,
            ),
            child: const Text('Đồng bộ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
