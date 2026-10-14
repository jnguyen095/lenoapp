import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../models/models.dart';

typedef PaymentInput = ({PaymentMethod method, double received});

/// Thanh toán (giống web): 2 nút to Tiền mặt / Chuyển khoản. Tiền mặt: nhập tiền khách đưa (nút "Đủ tiền" + gợi ý
/// mệnh giá) và hiện tiền thối. Chuyển khoản: hiện tài khoản nhận ([bankQr]) để đối chiếu trước khi xác nhận.
/// Trả về null nếu đóng. [onMethodChanged] báo mỗi lần chọn hình thức — vd để màn hình khách hiện mã VietQR.
Future<PaymentInput?> showPaymentSheet(
  BuildContext context, {
  required double total,
  required String title,
  BankQr? bankQr,
  ValueChanged<PaymentMethod>? onMethodChanged,
}) {
  return showModalBottomSheet<PaymentInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PaymentSheet(total: total, title: title, bankQr: bankQr, onMethodChanged: onMethodChanged),
    ),
  );
}

/// Gợi ý tiền khách đưa (giống web): 3 mức làm tròn lên gần nhất theo mệnh giá + mức tròn 500.000 kế tiếp (tờ lớn).
/// Vd 120.000 -> 150.000, 200.000, 500.000; 216.000 -> 220.000, 250.000, 300.000, 500.000;
/// 500.000 -> 600.000, 1.000.000. Không gồm "Đủ tiền" (nút riêng).
List<double> cashSuggestions(double total) {
  final t = total.roundToDouble();
  double up(int step) => (t / step).ceil() * step.toDouble();
  final out = <double>{
    for (final step in const [10000, 20000, 50000, 100000, 200000, 500000, 1000000])
      if (up(step) > t) up(step),
  }.toList()
    ..sort();
  final pick = out.take(3).toList();
  final big = up(500000) > t ? up(500000) : up(500000) + 500000;
  if (!pick.contains(big)) pick.add(big);
  return pick..sort();
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.total, required this.title, this.bankQr, this.onMethodChanged});

  final double total;
  final String title;
  final BankQr? bankQr;
  final ValueChanged<PaymentMethod>? onMethodChanged;

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

  void _setMethod(PaymentMethod m) {
    if (m == _method) return;
    setState(() => _method = m);
    widget.onMethodChanged?.call(m);
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
    final scheme = theme.colorScheme;
    final change = _receivedValue - widget.total;
    final total = widget.total.roundToDouble();
    final bank = widget.bankQr;

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
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Hình thức thanh toán', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (i, m) in PaymentMethod.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _MethodButton(
                          icon: m == PaymentMethod.cash ? Icons.payments_outlined : Icons.account_balance_outlined,
                          label: m.label,
                          selected: _method == m,
                          onTap: () => _setMethod(m),
                        ),
                      ),
                    ],
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
                      ThousandsInputFormatter(),
                    ],
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(labelText: 'Khách đưa', suffixText: 'đ'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: 10),
                  // "Đủ tiền" + gợi ý mệnh giá — bấm để điền nhanh; nút trùng số đang nhập được tô màu.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CashChip(
                        label: 'Đủ tiền',
                        exact: true,
                        active: _receivedValue == total,
                        onTap: () => _setReceived(total),
                      ),
                      for (final v in cashSuggestions(total))
                        _CashChip(
                          label: formatMoney(v, withUnit: false),
                          active: _receivedValue == v,
                          onTap: () => _setReceived(v),
                        ),
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
                          color: change >= 0 ? scheme.primary : scheme.error,
                        ),
                      ),
                    ],
                  ),
                ] else if (bank != null && bank.enabled)
                  // Chuyển khoản: tài khoản nhận (Cài đặt trên web) để đối chiếu — khách quét mã trên màn hình khách / phiếu.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.account_balance, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${bank.bankName} — ${bank.accountNo}',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              if (bank.accountName.isNotEmpty) Text(bank.accountName),
                              const SizedBox(height: 2),
                              Text(
                                'Kiểm tra đã nhận đủ tiền trước khi xác nhận. Nội dung chuyển khoản: số hóa đơn.',
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Xác nhận khi đã nhận đủ ${formatMoney(widget.total)} qua chuyển khoản.',
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

/// Nút chọn hình thức thanh toán: to, biểu tượng + chữ, viền màu chính khi chọn.
class _MethodButton extends StatelessWidget {
  const _MethodButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút gợi ý số tiền khách đưa. [exact] = "Đủ tiền" (tô xanh lá).
class _CashChip extends StatelessWidget {
  const _CashChip({required this.label, required this.active, required this.onTap, this.exact = false});

  final String label;
  final bool active;
  final bool exact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final green = Colors.green.shade700;
    final fg = active ? scheme.onPrimary : (exact ? green : scheme.onSurface);
    return Material(
      color: active ? scheme.primary : (exact ? Colors.green.shade50 : scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? scheme.primary : (exact ? Colors.green.shade200 : scheme.outlineVariant)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 84, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 150000 -> 150.000 khi đang gõ.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatMoney(int.parse(digits), withUnit: false);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
