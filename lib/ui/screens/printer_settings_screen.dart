import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../printing/print_settings.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import '../widgets/dialogs.dart';
import '../widgets/print_feedback.dart';
import 'printer_edit_screen.dart';

/// Cài đặt máy in của máy này: danh sách máy in LAN, tự động in, thông tin trên hóa đơn
/// và bảng "danh mục -> máy in".
class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, [PrinterConfig? printer]) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PrinterEditScreen(printer: printer)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(printSettingsProvider);
    final controller = ref.read(printSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt máy in')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm máy in'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const _SectionTitle('Máy in'),
                if (settings.printers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Chưa có máy in nào.\n\nBấm "Thêm máy in", nhập địa chỉ IP của máy in (in trang tự kiểm tra '
                        'của máy in để xem IP) hoặc dùng "Dò máy in" để tìm trong mạng LAN.',
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final p in settings.printers) ...[
                          _PrinterTile(printer: p, onTap: () => _edit(context, p)),
                          if (p != settings.printers.last) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                const _SectionTitle('Tự động in'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('In phiếu bếp khi bấm "Báo bếp"'),
                        subtitle: const Text('Tách phiếu theo danh mục ra từng máy in'),
                        value: settings.autoPrintKitchen,
                        onChanged: (v) => controller.save(settings.copyWith(autoPrintKitchen: v)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('In hóa đơn sau khi thanh toán'),
                        subtitle: const Text('Ra các máy in có bật "In hóa đơn / tạm tính"'),
                        value: settings.autoPrintReceipt,
                        onChanged: (v) => controller.save(settings.copyWith(autoPrintReceipt: v)),
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('Máy in theo danh mục'),
                _CategoryRouting(settings: settings),
                const _SectionTitle('Thông tin trên hóa đơn'),
                Card(
                  child: Column(
                    children: [
                      _TextSettingTile(
                        label: 'Tên quán',
                        value: settings.shopName,
                        onSaved: (v) => controller.save(settings.copyWith(shopName: v)),
                      ),
                      const Divider(height: 1),
                      _TextSettingTile(
                        label: 'Địa chỉ',
                        value: settings.shopAddress,
                        onSaved: (v) => controller.save(settings.copyWith(shopAddress: v)),
                      ),
                      const Divider(height: 1),
                      _TextSettingTile(
                        label: 'Lời cảm ơn cuối hóa đơn',
                        value: settings.footer,
                        onSaved: (v) => controller.save(settings.copyWith(footer: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cài đặt này lưu trên máy này. Mỗi máy tính bảng cần tự cài máy in của mình.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _PrinterTile extends ConsumerStatefulWidget {
  const _PrinterTile({required this.printer, required this.onTap});

  final PrinterConfig printer;
  final VoidCallback onTap;

  @override
  ConsumerState<_PrinterTile> createState() => _PrinterTileState();
}

class _PrinterTileState extends ConsumerState<_PrinterTile> {
  bool _printing = false;

  Future<void> _test() async {
    setState(() => _printing = true);
    final report = await ref.read(printActionsProvider).test(widget.printer);
    if (!mounted) return;
    setState(() => _printing = false);
    if (report.ok) showMessage(context, 'Đã gửi trang in thử tới "${widget.printer.name}".');
    showPrintReport(context, report, what: 'in thử');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.printer;
    final roles = [
      if (p.receipts) 'Hóa đơn',
      if (p.kitchenDefault) 'Bếp mặc định',
      if (p.categoryIds.isNotEmpty) '${p.categoryIds.length} danh mục',
      if (!p.enabled) 'Đang tắt',
    ];
    return ListTile(
      onTap: widget.onTap,
      leading: Icon(p.isUsb ? Icons.usb : Icons.print, color: p.enabled ? null : Theme.of(context).disabledColor),
      title: Text(p.name),
      subtitle: Text('${p.address} · ${p.paper.label}${roles.isEmpty ? '' : '\n${roles.join(' · ')}'}'),
      isThreeLine: roles.isNotEmpty,
      trailing: _printing
          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: p.enabled ? _test : null, child: const Text('In thử')),
    );
  }
}

/// Mỗi danh mục thực đơn đang in ra máy nào — để thấy ngay danh mục nào chưa có máy in.
class _CategoryRouting extends ConsumerWidget {
  const _CategoryRouting({required this.settings});

  final PrintSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(menuProvider).when(
          loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator())),
          error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Không tải được danh mục: $e'))),
          data: (categories) {
            final active = settings.activePrinters.toList();
            final defaults = active.where((p) => p.kitchenDefault).map((p) => p.name).toList();
            return Card(
              child: Column(
                children: [
                  for (final MenuCategory c in categories)
                    Builder(builder: (context) {
                      final assigned = active.where((p) => p.categoryIds.contains(c.id)).map((p) => p.name).toList();
                      final String text;
                      final Color? color;
                      if (assigned.isNotEmpty) {
                        text = assigned.join(', ');
                        color = null;
                      } else if (defaults.isNotEmpty) {
                        text = '${defaults.join(', ')} (mặc định)';
                        color = theme.colorScheme.onSurfaceVariant;
                      } else {
                        text = 'Chưa có máy in';
                        color = theme.colorScheme.error;
                      }
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        trailing: Text(text, style: TextStyle(color: color)),
                      );
                    }),
                ],
              ),
            );
          },
        );
  }
}

class _TextSettingTile extends StatelessWidget {
  const _TextSettingTile({required this.label, required this.value, required this.onSaved});

  final String label;
  final String value;
  final ValueChanged<String> onSaved;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.isEmpty ? '(trống)' : value),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        final v = await showNoteDialog(context, title: label, initial: value, quick: false);
        if (v != null) onSaved(v);
      },
    );
  }
}
