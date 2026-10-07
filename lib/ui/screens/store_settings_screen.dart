import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../printing/print_settings.dart';
import '../../state/printing.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dialogs.dart';

/// Cài đặt cửa hàng: thông tin in trên hóa đơn / phiếu tạm tính và hiện dưới tiêu đề "Sơ đồ bàn".
/// Lưu trên máy này (cùng chỗ với cài đặt máy in).
class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt cửa hàng'), actions: const [AppMenuButton()]),
      endDrawer: const AppDrawer(current: AppPage.store),
      body: ref.watch(printSettingsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (settings) => _StoreForm(settings: settings),
          ),
    );
  }
}

class _StoreForm extends ConsumerStatefulWidget {
  const _StoreForm({required this.settings});

  final PrintSettings settings;

  @override
  ConsumerState<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends ConsumerState<_StoreForm> {
  late final _name = TextEditingController(text: widget.settings.shopName);
  late final _address = TextEditingController(text: widget.settings.shopAddress);
  late final _phone = TextEditingController(text: widget.settings.shopPhone);
  late final _footer = TextEditingController(text: widget.settings.footer);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await ref.read(printSettingsProvider.notifier).change((s) => s.copyWith(
          shopName: _name.text.trim(),
          shopAddress: _address.text.trim(),
          shopPhone: _phone.text.trim(),
          footer: _footer.text.trim(),
        ));
    if (mounted) showMessage(context, 'Đã lưu cài đặt cửa hàng.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration deco(String label, IconData icon, {String? hint, String? helper}) =>
        InputDecoration(labelText: label, hintText: hint, helperText: helper, prefixIcon: Icon(icon));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Thông tin in trên hóa đơn và phiếu tạm tính', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: deco('Tên quán', Icons.storefront_outlined,
                  hint: 'Leno', helper: 'Dòng đầu hóa đơn, cũng hiện dưới tiêu đề "Sơ đồ bàn"'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              maxLength: 120,
              decoration: deco('Địa chỉ', Icons.place_outlined, hint: '28 Võ Văn Kiệt, BMT'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              maxLength: 20,
              keyboardType: TextInputType.phone,
              decoration: deco('Số điện thoại', Icons.phone_outlined, helper: 'Để trống nếu không muốn in'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _footer,
              maxLength: 120,
              decoration: deco('Lời cảm ơn cuối hóa đơn', Icons.favorite_border, hint: 'Cảm ơn quý khách - Hẹn gặp lại!'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.check),
              label: const Text('Lưu'),
            ),
            const SizedBox(height: 12),
            Text('Cài đặt này lưu trên máy này. Mỗi máy tính bảng cần tự cài.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
