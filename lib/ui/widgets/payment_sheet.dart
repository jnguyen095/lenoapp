import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../models/models.dart';

typedef PaymentInput = ({PaymentMethod method, double received});

/// Chọn hình thức thanh toán; tiền mặt thì nhập tiền khách đưa (có nút gợi ý mệnh giá) và
/// hiện tiền thối. Trả về null nếu đóng.
Future<PaymentInput?> showPaymentSheet(BuildContext context, {required double total, required String title}) {
  return showModalBottomSheet<PaymentInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PaymentSheet(total: total, title: title),
    ),
  );
}

/// Mệnh giá gợi ý: đúng số tiền và làm tròn lên các mốc tiền giấy hay dùng.
List<double> suggestedCash(double total) {
  final values = <double>{total};
  for (final step in const [10000, 20000, 50000, 100000, 200000, 500000]) {
    values.add((total / step).ceil() * step.toDouble());
  }
  final list = values.where((v) => v >= total && v > 0).toList()..sort();
  return list.take(6).toList();
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.total, required this.title});

  final double total;
  final String title;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _received = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  double get _receivedValue => double.tryParse(_received.text.replaceAll('.', '')) ?? 0;

  bool get _canConfirm => _method != PaymentMethod.cash || _receivedValue >= widget.total;

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  void _setReceived(double v) {
    final text = formatMoney(v, withUnit: false);
    _received.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    setState(() {});
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.pop<PaymentInput>(
      context,
      (method: _method, received: _method == PaymentMethod.cash ? _receivedValue : widget.total),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = _receivedValue - widget.total;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Thanh toán — ${widget.title}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  formatMoney(widget.total),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in PaymentMethod.values)
                      ChoiceChip(
                        label: Text(m.label),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_method == PaymentMethod.cash) ...[
                  TextField(
                    controller: _received,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                      _ThousandsFormatter(),
                    ],
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(labelText: 'Khách đưa', suffixText: 'đ'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in suggestedCash(widget.total))
                        ActionChip(label: Text(formatMoney(v, withUnit: false)), onPressed: () => _setReceived(v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Tiền thối', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        _received.text.isEmpty ? '—' : (change >= 0 ? formatMoney(change) : 'Chưa đủ ${formatMoney(-change)}'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: change >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'Xác nhận khi đã nhận đủ ${formatMoney(widget.total)} qua ${_method.label.toLowerCase()}.',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  icon: const Icon(Icons.check),
                  label: const Text('Xác nhận thanh toán', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 150000 -> 150.000 khi đang gõ.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatMoney(int.parse(digits), withUnit: false);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
