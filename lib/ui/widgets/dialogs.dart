import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/printing.dart';
import 'print_feedback.dart';

/// Ghi chú hay dùng ở quầy — bấm để thêm nhanh.
const quickNotes = ['Ít đá', 'Không đá', 'Ít đường', 'Không đường', 'Nhiều sữa', 'Ít sữa', 'Mang về'];

void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'Có lỗi xảy ra: $error';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
}

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Đồng ý',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Thôi')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Trả về ghi chú mới ('' = xoá ghi chú), hoặc null nếu bấm Thôi.
Future<String?> showNoteDialog(BuildContext context, {required String title, String? initial, bool quick = true}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NoteDialog(title: title, initial: initial, quick: quick),
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, this.initial, required this.quick});

  final String title;
  final String? initial;
  final bool quick;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 255,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Nhập ghi chú'),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            if (widget.quick) _QuickNoteChips(controller: _controller),
          ],
        ),
      ),
      actions: [
        if ((widget.initial ?? '').isNotEmpty)
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Xoá ghi chú')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Lưu')),
      ],
    );
  }
}

class _QuickNoteChips extends StatelessWidget {
  const _QuickNoteChips({required this.controller});

  final TextEditingController controller;

  void _append(String note) {
    final current = controller.text.trim();
    controller.text = current.isEmpty ? note : '$current, $note';
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final n in quickNotes) ActionChip(label: Text(n), onPressed: () => _append(n)),
      ],
    );
  }
}

/// Thêm món kèm số lượng và ghi chú (nhấn giữ món trên thực đơn).
Future<({int qty, String? note})?> showAddProductDialog(BuildContext context, Product product) {
  return showDialog<({int qty, String? note})>(
    context: context,
    builder: (context) => _AddProductDialog(product: product),
  );
}

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({required this.product});

  final Product product;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _note = TextEditingController();
  int _qty = 1;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    Navigator.pop(context, (qty: _qty, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.product.name),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatMoney(widget.product.price), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 64,
                  child: Text('$_qty', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                ),
                IconButton.filledTonal(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
              onSubmitted: (_) => _submit(),
            ),
            _QuickNoteChips(controller: _note),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
        FilledButton(
          onPressed: _submit,
          child: Text('Thêm · ${formatMoney(widget.product.price * _qty)}'),
        ),
      ],
    );
  }
}

/// Chọn một mục trong danh sách (vd bàn đích khi chuyển/gộp bàn).
Future<T?> showPickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  String? Function(T)? subtitle,
  String emptyText = 'Không có lựa chọn nào.',
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: options.isEmpty
          ? [Padding(padding: const EdgeInsets.all(24), child: Text(emptyText))]
          : [
              for (final o in options)
                ListTile(
                  title: Text(label(o)),
                  subtitle: subtitle?.call(o) == null ? null : Text(subtitle!(o)!),
                  onTap: () => Navigator.pop(context, o),
                ),
            ],
    ),
  );
}

/// Kết quả sau khi thanh toán (tiền thối lại cho khách).
Future<void> showReceiptDialog(BuildContext context, OrderDetail detail, {Future<PrintReport> Function()? onPrint}) {
  final p = detail.payment;
  final theme = Theme.of(context);

  Widget row(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: strong ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) : null),
          ],
        ),
      );

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 48),
      title: Text('Đã thanh toán — ${detail.order.tableName}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Mã đơn', detail.order.orderNo),
            row('Tổng tiền', formatMoney(detail.order.totalAmount), strong: true),
            if (p != null) ...[
              row('Hình thức', p.methodLabel),
              if (p.method == PaymentMethod.cash.code) ...[
                row('Khách đưa', formatMoney(p.receivedAmount)),
                row('Tiền thối', formatMoney(p.changeAmount), strong: true),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (onPrint != null) PrintButton(onPrint: onPrint, what: 'hóa đơn', label: 'In hóa đơn'),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
      ],
    ),
  );
}
