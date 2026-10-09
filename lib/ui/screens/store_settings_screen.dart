import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer_display/customer_display_controller.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dialogs.dart';
import 'customer_display_preview_screen.dart';

/// Cài đặt cửa hàng: thông tin in trên phiếu (tên quán, địa chỉ, SĐT, lời cảm ơn) lấy từ web
/// (Cài đặt → Thông tin in phiếu) — dùng chung cho mọi máy, chỉ xem ở đây. Kèm phần màn hình khách.
class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt cửa hàng'), actions: const [AppMenuButton()]),
      endDrawer: const AppDrawer(current: AppPage.store),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _ReceiptInfoSection(),
              SizedBox(height: 28),
              _CustomerDisplaySection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thông tin in trên phiếu tạm tính / phiếu tính tiền — sửa trên web, ứng dụng tự tải lại.
class _ReceiptInfoSection extends ConsumerStatefulWidget {
  const _ReceiptInfoSection();

  @override
  ConsumerState<_ReceiptInfoSection> createState() => _ReceiptInfoSectionState();
}

class _ReceiptInfoSectionState extends ConsumerState<_ReceiptInfoSection> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    String message = 'Đã tải thông tin mới nhất từ máy chủ.';
    try {
      await ref.read(shopSettingsProvider.notifier).refresh();
    } catch (e) {
      message = '$e';
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = ref.watch(shopSettingsProvider)?.receipt ?? const ReceiptInfo();

    Widget row(IconData icon, String label, String value) => ListTile(
          leading: Icon(icon),
          title: Text(label, style: theme.textTheme.bodySmall),
          subtitle: Text(value.isEmpty ? '(không in)' : value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: value.isEmpty ? theme.colorScheme.outline : null,
              )),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Thông tin in trên phiếu',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
            _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tải lại')),
          ],
        ),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              row(Icons.storefront_outlined, 'Tên quán', receipt.shopName),
              const Divider(height: 1),
              row(Icons.place_outlined, 'Địa chỉ', receipt.address),
              const Divider(height: 1),
              row(Icons.phone_outlined, 'Số điện thoại', receipt.phone),
              const Divider(height: 1),
              row(Icons.favorite_border, 'Lời cảm ơn cuối phiếu tính tiền', receipt.footer),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dùng chung cho mọi máy. Sửa trên web: Cài đặt → Thông tin in phiếu (quyền quản trị). '
          'Ứng dụng tự cập nhật khi mở ứng dụng và mỗi 5 phút.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Màn hình khách (màn hình phụ của máy POS): bật/tắt, trạng thái, tải lại ảnh, xem thử.
/// Ảnh trình chiếu và tuỳ chọn hiển thị quản lý trên web: Quản trị → Màn hình khách.
class _CustomerDisplaySection extends ConsumerStatefulWidget {
  const _CustomerDisplaySection();

  @override
  ConsumerState<_CustomerDisplaySection> createState() => _CustomerDisplaySectionState();
}

class _CustomerDisplaySectionState extends ConsumerState<_CustomerDisplaySection> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customerDisplayProvider.notifier).refreshStatus());
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final c = ref.read(customerDisplayProvider.notifier);
    await c.refreshStatus();
    await c.refreshContent();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final s = ref.read(customerDisplayProvider);
    showMessage(context, s.lastError == null ? 'Đã tải ${s.content.readySlides.length} ảnh và tuỳ chọn mới nhất.' : s.lastError!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(customerDisplayProvider);
    final c = ref.read(customerDisplayProvider.notifier);
    final info = s.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Màn hình khách', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Hiện trên màn hình phụ'),
                subtitle: Text(info.available
                    ? '${info.label}${info.showing ? ' · đang hiện' : ''}'
                    : 'Không tìm thấy màn hình phụ (máy POS 2 màn hình hoặc màn hình HDMI).'),
                value: s.enabled,
                onChanged: c.setEnabled,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('${s.content.readySlides.length} ảnh trình chiếu'),
                subtitle: Text(s.lastError ?? 'Quản lý ảnh và tuỳ chọn trên web: Quản trị → Màn hình khách. Tự tải lại mỗi 5 phút.'),
                trailing: _refreshing
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _refresh, child: const Text('Tải lại')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Xem thử màn hình khách'),
                subtitle: const Text('Xem trên máy này: lúc rảnh, gọi món, chuyển khoản, cảm ơn'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const CustomerDisplayPreviewScreen())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
