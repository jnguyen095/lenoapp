import 'package:flutter/material.dart';

import '../../state/printing.dart';
import 'dialogs.dart';

/// Nút "In" có vòng xoay khi đang gửi phiếu, báo kết quả bằng SnackBar.
class PrintButton extends StatefulWidget {
  const PrintButton({super.key, required this.onPrint, required this.what, this.label = 'In'});

  final Future<PrintReport> Function() onPrint;
  final String what;
  final String label;

  @override
  State<PrintButton> createState() => _PrintButtonState();
}

class _PrintButtonState extends State<PrintButton> {
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    final report = await widget.onPrint();
    if (!mounted) return;
    setState(() => _busy = false);
    if (report.ok && report.printed > 0) showMessage(context, 'Đã in ${widget.what}.');
    showPrintReport(context, report, what: widget.what, retry: widget.onPrint);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _print,
      icon: _busy
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.print_outlined),
      label: Text(widget.label),
    );
  }
}

/// Báo kết quả in bằng SnackBar; in lỗi thì có nút "In lại".
void showPrintReport(
  BuildContext context,
  PrintReport report, {
  required String what,
  Future<PrintReport> Function()? retry,
  bool quietWhenNotConfigured = false,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  if (report.notConfigured) {
    if (quietWhenNotConfigured) return;
    showMessage(context, 'Chưa cài máy in cho $what. Vào Cài đặt máy in để thêm.');
    return;
  }

  if (!report.ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(report.errors.join('\n')),
        action: retry == null
            ? null
            : SnackBarAction(
                label: 'In lại',
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: () async {
                  final again = await retry();
                  if (context.mounted) showPrintReport(context, again, what: what, retry: retry);
                },
              ),
      ));
    return;
  }

  if (report.warnings.isNotEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text(report.warnings.join('\n'))));
  }
}
