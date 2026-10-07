import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../printing/print_settings.dart';
import '../../printing/printer_service.dart';
import '../../printing/usb_printer.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import '../widgets/dialogs.dart';
import '../widgets/print_feedback.dart';

/// Thêm / sửa một máy in (mạng LAN hoặc USB) và chọn danh mục thực đơn in ra máy này.
class PrinterEditScreen extends ConsumerStatefulWidget {
  const PrinterEditScreen({super.key, this.printer});

  /// null = thêm máy in mới.
  final PrinterConfig? printer;

  @override
  ConsumerState<PrinterEditScreen> createState() => _PrinterEditScreenState();
}

class _PrinterEditScreenState extends ConsumerState<PrinterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.printer?.name ?? '');
  late final _host = TextEditingController(text: widget.printer?.host ?? '');
  late final _port = TextEditingController(text: '${widget.printer?.port ?? 9100}');
  late PrinterConnection _connection =
      widget.printer?.connection ?? (UsbPrinters.supported ? PrinterConnection.usb : PrinterConnection.lan);
  late UsbPrinterDevice? _usb = widget.printer?.usbVendorId == null
      ? null
      : UsbPrinterDevice(
          vendorId: widget.printer!.usbVendorId!,
          productId: widget.printer!.usbProductId!,
          deviceName: widget.printer!.usbDeviceName ?? '',
          productName: widget.printer!.usbLabel,
        );
  late PaperWidth _paper = widget.printer?.paper ?? PaperWidth.mm80;
  late Set<int> _categories = {...?widget.printer?.categoryIds};
  late bool _receipts = widget.printer?.receipts ?? false;
  late bool _kitchenDefault = widget.printer?.kitchenDefault ?? false;
  late bool _enabled = widget.printer?.enabled ?? true;

  bool _testing = false;
  bool _scanning = false;

  bool get _isNew => widget.printer == null;
  bool get _isUsb => _connection == PrinterConnection.usb;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  String get _defaultName => _isUsb ? (_usb?.label ?? 'Máy in USB') : 'Máy in ${_host.text.trim()}';

  PrinterConfig _current() => PrinterConfig(
        id: widget.printer?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim().isEmpty ? _defaultName : _name.text.trim(),
        connection: _connection,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 9100,
        usbVendorId: _isUsb ? _usb?.vendorId : null,
        usbProductId: _isUsb ? _usb?.productId : null,
        usbDeviceName: _isUsb ? _usb?.deviceName : null,
        usbLabel: _isUsb ? _usb?.label : null,
        paper: _paper,
        categoryIds: _categories,
        receipts: _receipts,
        kitchenDefault: _kitchenDefault,
        enabled: _enabled,
      );

  /// Form hợp lệ + (USB) đã chọn máy in.
  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    if (_isUsb && _usb == null) {
      showMessage(context, 'Bấm "Chọn máy in USB" để chọn máy in đang cắm.');
      return false;
    }
    return true;
  }

  Future<void> _pickUsb() async {
    List<UsbPrinterDevice> devices;
    try {
      devices = await UsbPrinters.list();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await showPickerDialog<UsbPrinterDevice>(
      context,
      title: 'Máy in USB đang cắm',
      options: devices,
      label: (d) => d.label,
      subtitle: (d) => '${d.ids}${d.hasPermission ? '' : ' · cần cho phép'}',
      emptyText: 'Không thấy máy in USB nào.\n\nKiểm tra máy in đã bật và cắm cáp USB vào máy POS '
          '(máy tính bảng cần cáp OTG). Máy in tích hợp sẵn trong máy POS có thể không hiện ở đây.',
    );
    if (picked == null || !mounted) return;
    setState(() => _usb = picked);
    if (!picked.hasPermission) {
      final ok = await UsbPrinters.requestPermission(picked.vendorId, picked.productId, deviceName: picked.deviceName);
      if (mounted && !ok) showMessage(context, 'Chưa được cho phép dùng máy in USB này. Sẽ hỏi lại khi in.');
    }
  }

  Future<void> _save() async {
    if (!_validate()) return;
    await ref.read(printSettingsProvider.notifier).change((s) => s.upsertPrinter(_current()));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context,
        title: 'Xoá máy in "${widget.printer!.name}"?', confirmLabel: 'Xoá', destructive: true)) {
      return;
    }
    await ref.read(printSettingsProvider.notifier).change((s) => s.removePrinter(widget.printer!.id));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _test() async {
    if (!_validate()) return;
    setState(() => _testing = true);
    final report = await ref.read(printActionsProvider).test(_current());
    if (!mounted) return;
    setState(() => _testing = false);
    if (report.ok) showMessage(context, 'Đã gửi trang in thử. Kiểm tra máy in đã ra giấy chưa.');
    showPrintReport(context, report, what: 'in thử');
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    List<String> found;
    try {
      found = await PrinterService.discover(port: int.tryParse(_port.text.trim()) ?? 9100);
    } catch (e) {
      found = const [];
    }
    if (!mounted) return;
    setState(() => _scanning = false);
    final host = await showPickerDialog<String>(
      context,
      title: 'Máy in tìm thấy',
      options: found,
      label: (h) => h,
      emptyText: 'Không tìm thấy máy in nào mở cổng ${_port.text} trong mạng này.\n'
          'Kiểm tra máy in đã bật, cắm dây LAN cùng mạng với máy tính bảng, hoặc nhập IP thủ công.',
    );
    if (host != null) setState(() => _host.text = host);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuAsync = ref.watch(menuProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Thêm máy in' : 'Sửa máy in'),
        actions: [
          if (!_isNew) IconButton(tooltip: 'Xoá máy in', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: _testing
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print_outlined),
                  label: const Text('In thử'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.check),
                  label: const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Tên máy in',
                    hintText: 'Vd: Quầy bar, Bếp, Thu ngân',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Kết nối', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<PrinterConnection>(
                  segments: const [
                    ButtonSegment(value: PrinterConnection.lan, icon: Icon(Icons.lan_outlined), label: Text('Mạng LAN')),
                    ButtonSegment(value: PrinterConnection.usb, icon: Icon(Icons.usb), label: Text('USB')),
                  ],
                  selected: {_connection},
                  onSelectionChanged: (s) => setState(() => _connection = s.first),
                ),
                const SizedBox(height: 16),
                if (_isUsb) ...[
                  if (!UsbPrinters.supported)
                    Text('Máy in USB chỉ dùng được khi chạy ứng dụng trên máy Android (máy POS / máy tính bảng).',
                        style: TextStyle(color: theme.colorScheme.error)),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.usb),
                      title: Text(_usb?.label ?? 'Chưa chọn máy in'),
                      subtitle: Text(_usb == null ? 'Cắm máy in vào cổng USB rồi bấm Chọn' : 'Mã USB ${_usb!.ids}'),
                      trailing: FilledButton.tonal(
                        onPressed: UsbPrinters.supported ? _pickUsb : null,
                        child: Text(_usb == null ? 'Chọn máy in USB' : 'Đổi'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _host,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ IP',
                            hintText: '192.168.1.100',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                          validator: (v) => _isUsb || (v ?? '').trim().isNotEmpty ? null : 'Nhập địa chỉ IP của máy in',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Cổng'),
                          validator: (v) {
                            if (_isUsb) return null;
                            final p = int.tryParse(v ?? '');
                            return p == null || p < 1 || p > 65535 ? 'Sai cổng' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.radar),
                      label: Text(_scanning ? 'Đang dò máy in trong mạng…' : 'Dò máy in trong mạng LAN'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Khổ giấy', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in PaperWidth.values)
                      ChoiceChip(label: Text(p.label), selected: _paper == p, onSelected: (_) => setState(() => _paper = p)),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('In hóa đơn / phiếu tạm tính'),
                        subtitle: const Text('Máy in ở quầy thu ngân'),
                        value: _receipts,
                        onChanged: (v) => setState(() => _receipts = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Máy bếp mặc định'),
                        subtitle: const Text('Nhận phiếu bếp của các danh mục chưa gán máy in nào'),
                        value: _kitchenDefault,
                        onChanged: (v) => setState(() => _kitchenDefault = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Đang dùng'),
                        subtitle: const Text('Tắt tạm thời khi máy in hỏng, không cần xoá cài đặt'),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Text('Danh mục in phiếu bếp ra máy này', style: theme.textTheme.titleSmall)),
                    menuAsync.maybeWhen(
                      data: (cats) => TextButton(
                        onPressed: () => setState(() {
                          _categories = _categories.length == cats.length ? {} : cats.map((c) => c.id).toSet();
                        }),
                        child: Text(_categories.length == cats.length ? 'Bỏ chọn hết' : 'Chọn tất cả'),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                menuAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Không tải được danh mục: $e'),
                  data: (cats) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in cats)
                        FilterChip(
                          label: Text(c.name),
                          selected: _categories.contains(c.id),
                          onSelected: (on) => setState(() => on ? _categories.add(c.id) : _categories.remove(c.id)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vd: máy quầy bar chọn Cà phê, Trà sữa, Nước ép…; máy bếp chọn Đồ ăn vặt. '
                  'Một danh mục có thể in ra nhiều máy.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
