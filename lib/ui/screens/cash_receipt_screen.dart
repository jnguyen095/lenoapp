import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/printing.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dialogs.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/print_feedback.dart';

/// Loại thu + phiếu thu người này đã lập hôm nay (tải mới mỗi lần mở).
final cashReceiptsProvider =
    FutureProvider.autoDispose<CashReceiptsData>((ref) => ref.watch(posRepositoryProvider).cashReceipts());

/// Sổ quỹ trên ứng dụng: chỉ lập phiếu thu (tiền mặt / chuyển khoản), in phiếu, xem lại phiếu đã lập hôm nay.
/// Xem toàn bộ sổ quỹ, sửa / xoá phiếu, phiếu chi: làm trên web (Sổ quỹ).
class CashReceiptScreen extends ConsumerWidget {
  const CashReceiptScreen({super.key});

  Future<void> _print(BuildContext context, WidgetRef ref, CashReceipt r) async {
    Future<PrintReport> run() => ref.read(printActionsProvider).cashReceipt(r);
    final report = await run();
    if (context.mounted) showPrintReport(context, report, what: 'phiếu thu', retry: run);
  }

  Future<void> _create(BuildContext context, WidgetRef ref, CashReceiptsData data) async {
    final result = await showModalBottomSheet<({CashReceipt receipt, bool print})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _CashReceiptForm(data: data),
      ),
    );
    if (result == null || !context.mounted) return;
    ref.invalidate(cashReceiptsProvider);
    showMessage(context, 'Đã lập phiếu thu ${result.receipt.entryNo}: ${formatMoney(result.receipt.amount)}.');
    if (result.print) await _print(context, ref, result.receipt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashReceiptsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lập phiếu thu'),
            Text('Sổ quỹ', style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(cashReceiptsProvider)),
          const AppMenuButton(),
        ],
      ),
      endDrawer: const AppDrawer(current: AppPage.cashbook),
      floatingActionButton: async.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context, ref, async.value!),
              icon: const Icon(Icons.add),
              label: const Text('Lập phiếu thu'),
            ),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('$e', textAlign: TextAlign.center)),
              FilledButton(onPressed: () => ref.invalidate(cashReceiptsProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(cashReceiptsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tổng phiếu thu bạn lập hôm nay.
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: scheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_outlined, color: scheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Phiếu thu bạn lập hôm nay (${data.receipts.length})',
                                    style: theme.textTheme.bodyMedium),
                              ),
                              Text(formatMoney(data.total),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (data.receipts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 56),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: scheme.outline),
                              const SizedBox(height: 12),
                              Text('Hôm nay bạn chưa lập phiếu thu nào.',
                                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text('Bấm "Lập phiếu thu" để ghi khoản tiền nhận ngoài bán hàng.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
                            ],
                          ),
                        )
                      else
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          child: Column(
                            children: [
                              for (final r in data.receipts) ...[
                                _ReceiptTile(receipt: r, onPrint: () => _print(context, ref, r)),
                                if (r != data.receipts.last) const Divider(height: 1, indent: 64),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Tiền bán hàng tự vào sổ quỹ, không cần lập phiếu. Sửa / xoá phiếu, phiếu chi: làm trên web (Sổ quỹ).',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt, required this.onPrint});

  final CashReceipt receipt;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = receipt;
    final time = formatDateTime(r.entryDate).split(' ').last;
    final details = [
      r.categoryName,
      if ((r.counterparty ?? '').isNotEmpty) r.counterparty,
      r.methodLabel,
    ].whereType<String>().join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(r.paymentMethod == PaymentMethod.transfer.code ? Icons.account_balance_outlined : Icons.payments_outlined,
            color: scheme.primary, size: 20),
      ),
      title: Text('${r.entryNo} · $time', style: theme.textTheme.titleSmall),
      subtitle: Text(
        (r.note ?? '').isEmpty ? details : '$details\n${r.note}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatMoney(r.amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(tooltip: 'In lại phiếu thu', icon: const Icon(Icons.print_outlined), onPressed: onPrint),
        ],
      ),
    );
  }
}

/// Biểu mẫu lập phiếu thu: hình thức, số tiền, loại thu, người nộp (gợi ý tên đã dùng), ghi chú, in sau khi lưu.
class _CashReceiptForm extends ConsumerStatefulWidget {
  const _CashReceiptForm({required this.data});

  final CashReceiptsData data;

  @override
  ConsumerState<_CashReceiptForm> createState() => _CashReceiptFormState();
}

class _CashReceiptFormState extends ConsumerState<_CashReceiptForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TextEditingController? _counterparty; // của ô Autocomplete
  PaymentMethod _method = PaymentMethod.cash;
  late int? _categoryId = widget.data.categories.firstOrNull?.id;
  bool _print = true;
  bool _saving = false;
  String? _error;

  double get _amountValue => double.tryParse(_amount.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final categoryId = _categoryId;
    if (_saving) return;
    if (categoryId == null) return setState(() => _error = 'Chọn loại thu.');
    if (_amountValue <= 0) return setState(() => _error = 'Nhập số tiền thu (lớn hơn 0).');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final receipt = await ref.read(posRepositoryProvider).createCashReceipt(
            categoryId: categoryId,
            method: _method,
            amount: _amountValue,
            counterparty: _counterparty?.text.trim(),
            note: _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop((receipt: receipt, print: _print));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = widget.data.categories;

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
                Text('Lập phiếu thu', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SegmentedButton<PaymentMethod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: PaymentMethod.cash, icon: Icon(Icons.payments_outlined), label: Text('Tiền mặt')),
                    ButtonSegment(
                        value: PaymentMethod.transfer, icon: Icon(Icons.account_balance_outlined), label: Text('Chuyển khoản')),
                  ],
                  selected: {_method},
                  onSelectionChanged: (s) => setState(() => _method = s.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                    ThousandsInputFormatter(),
                  ],
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: 'Số tiền thu', suffixText: 'đ'),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 14),
                Text('Loại thu', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                if (categories.isEmpty)
                  Text('Chưa có loại thu — quản trị thêm trên web (Sổ quỹ → Loại thu chi).',
                      style: TextStyle(color: scheme.error))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                // Người nộp: gõ hoặc chọn tên đã dùng.
                Autocomplete<String>(
                  optionsBuilder: (v) {
                    final q = foldVietnamese(v.text.trim());
                    if (q.isEmpty) return widget.data.counterparties.take(8);
                    return widget.data.counterparties.where((s) => foldVietnamese(s).contains(q)).take(8);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    _counterparty = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLength: 150,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Người nộp (không bắt buộc)',
                        prefixIcon: Icon(Icons.person_outline),
                        counterText: '',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                    prefixIcon: Icon(Icons.notes),
                    counterText: '',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In phiếu thu sau khi lưu'),
                  value: _print,
                  onChanged: (v) => setState(() => _print = v),
                ),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  icon: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(
                    _amountValue > 0 ? 'Lưu phiếu thu · ${formatMoney(_amountValue)}' : 'Lưu phiếu thu',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
