import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import '../widgets/app_drawer.dart';
import 'order_screen.dart';

enum _Filter { all, open, paid }

/// Lịch sử đơn hàng: các đơn do người đang đăng nhập tạo hôm nay, mới nhất trước.
/// Bấm một đơn để xem lại (đơn đang phục vụ thì gọi món tiếp được).
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  _Filter _filter = _Filter.all;

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
          };

          return RefreshIndicator(
            onRefresh: () => ref.refresh(orderHistoryProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Số đơn',
                                value: '${history.orders.length}',
                                icon: Icons.receipt_long,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Đã thanh toán (${history.paidCount})',
                                value: formatMoney(history.paidTotal),
                                icon: Icons.check_circle_outline,
                                highlight: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Đang phục vụ (${history.openCount})',
                                value: formatMoney(history.openTotal),
                                icon: Icons.room_service_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _MethodTotals(totals: history.byMethod),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final (f, label) in [
                              (_Filter.all, 'Tất cả (${history.orders.length})'),
                              (_Filter.open, 'Đang phục vụ (${history.openCount})'),
                              (_Filter.paid, 'Đã thanh toán (${history.paidCount})'),
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: _filter == f,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  history.orders.isEmpty ? 'Hôm nay bạn chưa tạo đơn nào.' : 'Không có đơn nào.',
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.highlight = false});

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    return Card(
      elevation: 0,
      color: highlight ? scheme.primary : scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 2, style: theme.textTheme.labelMedium?.copyWith(color: fg, height: 1.2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
    // Luôn hiện giờ mở đơn (danh sách sắp theo giờ này); đơn đã trả thêm giờ thanh toán.
    final details = [
      'Mở lúc ${hhmm(order.createdAt)}',
      if (order.isPaid && order.paidAt != null) 'trả ${hhmm(order.paidAt)}',
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

/// Tiền đã thu theo hình thức: Tiền mặt và Chuyển khoản luôn hiện; Thẻ / QR chỉ hiện khi có đơn.
class _MethodTotals extends StatelessWidget {
  const _MethodTotals({required this.totals});

  final List<MethodTotal> totals;

  static const _alwaysShown = {'CASH', 'TRANSFER'};

  static IconData _icon(String method) => switch (method) {
        'CASH' => Icons.payments_outlined,
        'TRANSFER' => Icons.account_balance_outlined,
        'CARD' => Icons.credit_card,
        'QR' => Icons.qr_code_2,
        _ => Icons.attach_money,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = totals.where((t) => _alwaysShown.contains(t.method) || t.count > 0).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã thu theo hình thức', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final t in shown) ...[
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(_icon(t.method), size: 20, color: scheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t.label} (${t.count})',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(formatMoney(t.total),
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (t != shown.last) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
