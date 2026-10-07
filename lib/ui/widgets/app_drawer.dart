import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth.dart';
import '../screens/order_history_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/store_settings_screen.dart';
import 'dialogs.dart';

/// Trang đang mở — để mục tương ứng trong menu được tô đậm và không mở chồng thêm lần nữa.
enum AppPage { home, order, history, printers, store }

/// Nút ☰ đặt cuối thanh tiêu đề ở các trang con (đầu trang đã có nút quay lại).
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu),
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}

/// Menu chung: thông tin tài khoản, Cài đặt máy in, Cài đặt cửa hàng, Đăng xuất.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.current});

  final AppPage current;

  Future<void> _open(BuildContext context, AppPage page, Widget screen) async {
    Navigator.of(context).pop(); // đóng menu
    if (page == current) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = session?.user;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hồ sơ người đang đăng nhập.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: scheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.onPrimary,
                    child: Text(
                      (user?.fullname.isNotEmpty ?? false) ? user!.fullname.characters.first.toUpperCase() : '?',
                      style: theme.textTheme.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.fullname ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${user?.roleLabel ?? ''} · ${user?.username ?? ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.dns_outlined, size: 14, color: scheme.onPrimary.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          session?.serverUrl ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (current != AppPage.home)
              ListTile(
                leading: const Icon(Icons.table_restaurant_outlined),
                title: const Text('Sơ đồ bàn'),
                onTap: () {
                  Navigator.of(context)
                    ..pop()
                    ..popUntil((route) => route.isFirst);
                },
              ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Lịch sử đơn hàng'),
              subtitle: const Text('Đơn bạn tạo hôm nay'),
              selected: current == AppPage.history,
              onTap: () => _open(context, AppPage.history, const OrderHistoryScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Cài đặt máy in'),
              selected: current == AppPage.printers,
              onTap: () => _open(context, AppPage.printers, const PrinterSettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Cài đặt cửa hàng'),
              subtitle: const Text('Tên quán, địa chỉ, lời cảm ơn…'),
              selected: current == AppPage.store,
              onTap: () => _open(context, AppPage.store, const StoreSettingsScreen()),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Đăng xuất', style: TextStyle(color: scheme.error)),
              onTap: () async {
                Navigator.of(context).pop();
                if (await confirmDialog(context, title: 'Đăng xuất khỏi máy này?', confirmLabel: 'Đăng xuất')) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
