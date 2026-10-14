import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/printing.dart';
import '../widgets/app_drawer.dart';
import '../widgets/print_feedback.dart';

/// Báo cáo cuối ngày của người đang đăng nhập (tải mới mỗi lần mở / bấm tải lại).
final shiftReportProvider =
    FutureProvider.autoDispose<ShiftReport>((ref) => ref.watch(posRepositoryProvider).shiftReport());

/// Báo cáo cuối ngày: nhân viên, từ đầu ngày (00:00) tới bây giờ, số đơn (đã thanh toán / đang phục vụ / đã huỷ),
/// tiền mặt, chuyển khoản, tổng thu — in ra máy in hóa đơn để bàn giao ca.
class ShiftReportScreen extends ConsumerStatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  ConsumerState<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends ConsumerState<ShiftReportScreen> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      // Lấy số liệu mới nhất ngay lúc in.
      final report = await ref.refresh(shiftReportProvider.future);
      Future<PrintReport> run() => ref.read(printActionsProvider).shiftReport(report);
      final result = await run();
      if (mounted) showPrintReport(context, result, what: 'báo cáo', retry: run);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shiftReportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo cuối ngày'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(shiftReportProvider),
          ),
          const AppMenuButton(),
        ],
      ),
      endDrawer: const AppDrawer(current: AppPage.report),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('$e', textAlign: TextAlign.center)),
              FilledButton(onPressed: () => ref.invalidate(shiftReportProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(shiftReportProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        children: [
                          _Line(icon: Icons.person_outline, label: 'Nhân viên', value: r.fullname.isEmpty ? r.username : r.fullname),
                          _Line(
                            icon: Icons.login,
                            label: 'Từ',
                            value: formatDateTime(r.from),
                            note: 'đầu ngày',
                          ),
                          _Line(icon: Icons.schedule, label: 'Đến', value: formatDateTime(r.to), note: 'bây giờ'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Đơn hàng',
                        children: [
                          _Line(icon: Icons.receipt_long_outlined, label: 'Số đơn', value: '${r.orderCount}', bold: true),
                          _Line(icon: Icons.check_circle_outline, label: 'Đã thanh toán', value: '${r.paidCount}'),
                          if (r.openCount > 0)
                            _Line(
                              icon: Icons.room_service_outlined,
                              label: 'Đang phục vụ',
                              value: '${r.openCount} · ${formatMoney(r.openTotal)}',
                              color: Colors.orange.shade800,
                            ),
                          _Line(
                            icon: Icons.cancel_outlined,
                            label: 'Đã huỷ',
                            value: '${r.cancelledCount}',
                            color: r.cancelledCount > 0 ? theme.colorScheme.error : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Bán hàng',
                        children: [
                          _Line(
                            icon: Icons.payments_outlined,
                            label: 'Tiền mặt (${r.countOf(PaymentMethod.cash.code)})',
                            value: formatMoney(r.totalOf(PaymentMethod.cash.code)),
                          ),
                          _Line(
                            icon: Icons.account_balance_outlined,
                            label: 'Chuyển khoản (${r.countOf(PaymentMethod.transfer.code)})',
                            value: formatMoney(r.totalOf(PaymentMethod.transfer.code)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Phiếu thu sổ quỹ bạn thu (Lập phiếu thu).
                      _Section(
                        title: 'Phiếu thu (${r.receiptCount})',
                        children: [
                          _Line(
                            icon: Icons.payments_outlined,
                            label: 'Tiền mặt (${r.receiptCountOf(PaymentMethod.cash.code)})',
                            value: formatMoney(r.receiptTotalOf(PaymentMethod.cash.code)),
                          ),
                          _Line(
                            icon: Icons.account_balance_outlined,
                            label: 'Chuyển khoản (${r.receiptCountOf(PaymentMethod.transfer.code)})',
                            value: formatMoney(r.receiptTotalOf(PaymentMethod.transfer.code)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Tổng theo hình thức: tổng tiền mặt = số phải có trong két.
                      _Section(
                        title: 'Tổng cộng',
                        children: [
                          _Line(
                            icon: Icons.point_of_sale_outlined,
                            label: 'Tổng tiền mặt',
                            note: 'bán hàng + phiếu thu',
                            value: formatMoney(r.allOf(PaymentMethod.cash.code)),
                            bold: true,
                          ),
                          _Line(
                            icon: Icons.account_balance_outlined,
                            label: 'Tổng chuyển khoản',
                            value: formatMoney(r.allOf(PaymentMethod.transfer.code)),
                            bold: true,
                          ),
                          const Divider(height: 16),
                          _Line(
                            icon: Icons.summarize_outlined,
                            label: 'Tổng thu',
                            value: formatMoney(r.grandTotal),
                            bold: true,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _printing ? null : _print,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        icon: _printing
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.print_outlined),
                        label: const Text('In báo cáo', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bán hàng = các lần thanh toán bạn xác nhận. Phiếu thu = phiếu bạn thu (Lập phiếu thu). Số đơn = đơn bạn tạo (không tính đơn chưa có món).',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
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

class _Section extends StatelessWidget {
  const _Section({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value, this.note, this.bold = false, this.color});

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
        ?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (note != null)
                  Text(note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
