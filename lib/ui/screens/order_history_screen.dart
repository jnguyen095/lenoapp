import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import '../widgets/app_drawer.dart';
import 'order_screen.dart';

enum _Filter { all, open, paid }

/// Lịch sử đơn hàng: đơn người đang đăng nhập tạo — đã thanh toán hôm nay (theo giờ thanh toán, khớp Sổ quỹ) và
/// đang mở / đã huỷ mở hôm nay; mới đóng / mới mở trước.
/// Bấm một đơn để xem lại (đơn đang phục vụ thì gọi món tiếp được).
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  _Filter _filter = _Filter.all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Tìm theo số hóa đơn (gõ vài số cuối cũng được), tên bàn, ghi chú — không cần gõ dấu.
  static bool _matches(HistoryOrder o, String query) {
    final q = foldVietnamese(query.trim());
    if (q.isEmpty) return true;
    return [o.orderNo, o.tableName, o.note ?? ''].any((s) => foldVietnamese(s).contains(q));
  }

  Future<void> _open(HistoryOrder o) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: o.id)));
    ref.invalidate(orderHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lịch sử đơn hàng'),
            Text(
              historyAsync.valueOrNull == null ? 'Hôm nay' : 'Hôm nay, ${_dayLabel(historyAsync.value!.date)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: const [AppMenuButton()],
      ),
      endDrawer: const AppDrawer(current: AppPage.history),
      body: historyAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(orderHistoryProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (history) {
          final shown = switch (_filter) {
            _Filter.all => history.orders,
            _Filter.open => history.orders.where((o) => o.isActive).toList(),
            _Filter.paid => history.orders.where((o) => o.isPaid).toList(),
          }.where((o) => _matches(o, _query)).toList();
          final narrow = MediaQuery.sizeOf(context).width < 600;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(orderHistoryProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tổng kết gọn: số đơn, đã thanh toán, đang phục vụ + tiền theo hình thức trong một thẻ.
                        _SummaryCard(history: history),
                        const SizedBox(height: 8),
                        // Ô tìm + bộ lọc trên cùng một hàng.
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: _search,
                                  textInputAction: TextInputAction.search,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: theme.textTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    hintText: narrow ? 'Tìm số HĐ, bàn…' : 'Tìm theo số HĐ, tên bàn, ghi chú (vd: 0192, ban 3)',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHigh,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Xoá',
                                            iconSize: 18,
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _search.clear();
                                              setState(() => _query = '');
                                            },
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SegmentedButton<_Filter>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: theme.textTheme.labelMedium,
                              ),
                              segments: [
                                ButtonSegment(
                                    value: _Filter.all,
                                    label: Text(narrow ? 'Tất cả ${history.orders.length}' : 'Tất cả (${history.orders.length})')),
                                ButtonSegment(
                                    value: _Filter.open,
                                    label: Text(narrow ? 'Phục vụ ${history.openCount}' : 'Đang phục vụ (${history.openCount})')),
                                ButtonSegment(
                                    value: _Filter.paid,
                                    label: Text(narrow ? 'Đã TT ${history.paidCount}' : 'Đã thanh toán (${history.paidCount})')),
                              ],
                              selected: {_filter},
                              onSelectionChanged: (s) => setState(() => _filter = s.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  history.orders.isEmpty
                                      ? 'Hôm nay bạn chưa tạo đơn nào.'
                                      : (_query.trim().isNotEmpty ? 'Không tìm thấy đơn "${_query.trim()}".' : 'Không có đơn nào.'),
                                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        else
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: Column(
                              children: [
                                for (final o in shown) ...[
                                  _OrderTile(order: o, onTap: () => _open(o)),
                                  if (o != shown.last) const Divider(height: 1, indent: 72),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _dayLabel(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final HistoryOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (IconData icon, Color color) = switch (order.status) {
      Status.paid => (Icons.check_circle, scheme.primary),
      Status.cancelled => (Icons.cancel_outlined, scheme.error),
      _ => (Icons.room_service, const Color(0xFFEF6C00)),
    };
    String hhmm(String? t) => formatTime(t).split(' ').first;
    // Đơn đã thanh toán: giờ đóng đơn trước (danh sách và doanh thu tính theo giờ này, khớp Sổ quỹ), kèm giờ mở —
    // mở từ hôm khác thì ghi cả ngày. Đơn đang mở / đã huỷ: giờ mở.
    final paid = order.isPaid && order.paidAt != null;
    final openedOtherDay = paid && (order.createdAt ?? '').split(' ').first != order.paidAt!.split(' ').first;
    final details = [
      if (paid) ...[
        'Đóng lúc ${hhmm(order.paidAt)}',
        openedOtherDay ? 'mở ${formatTime(order.createdAt)}' : 'mở ${hhmm(order.createdAt)}',
      ] else
        'Mở lúc ${hhmm(order.createdAt)}',
      '${order.itemCount} món',
      ?order.methodLabel,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(order.tableName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${order.orderNo}\n$details'),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatMoney(order.totalAmount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(Status.orderLabel(order.status), style: theme.textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}


/// Tổng kết gọn trong một thẻ: Số đơn · Đã thanh toán · Đang phục vụ, dưới là tiền theo hình thức
/// (Tiền mặt, Chuyển khoản luôn hiện; hình thức cũ chỉ hiện khi có đơn).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.history});

  final OrderHistory history;

  static IconData _icon(String method) => switch (method) {
        'CASH' => Icons.payments_outlined,
        'TRANSFER' => Icons.account_balance_outlined,
        _ => Icons.attach_money,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final methods =
        history.byMethod.where((t) => t.method == 'CASH' || t.method == 'TRANSFER' || t.count > 0).toList();

    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                stat('Số đơn', '${history.orders.length}'),
                stat('Đã thanh toán (${history.paidCount})', formatMoney(history.paidTotal), color: scheme.primary),
                stat('Đang phục vụ (${history.openCount})', formatMoney(history.openTotal),
                    color: history.openCount > 0 ? Colors.orange.shade800 : null),
              ],
            ),
            if (methods.isNotEmpty) ...[
              const Divider(height: 12),
              Row(
                children: [
                  for (final t in methods)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(_icon(t.method), size: 16, color: scheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('${t.label} (${t.count})',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                          ),
                          const SizedBox(width: 6),
                          Text(formatMoney(t.total),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
