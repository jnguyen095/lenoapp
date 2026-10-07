import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import 'print_feedback.dart';

/// Nội dung một lần báo bếp: MÓN MỚI / ĐỔI GHI CHÚ / HỦY.
class KitchenSlipView extends StatelessWidget {
  const KitchenSlipView({super.key, required this.slip});

  final KitchenSlip slip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget section(String title, List<SlipLine> lines, Color color, {bool showOld = false}) {
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${l.qty} × ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: l.productName),
                  if (showOld && (l.oldNote ?? '').isNotEmpty)
                    TextSpan(
                      text: '\n   (cũ: ${l.oldNote})',
                      style: const TextStyle(decoration: TextDecoration.lineThrough),
                    ),
                  if ((l.note ?? '').isNotEmpty)
                    TextSpan(text: '\n   ${l.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  if (showOld && (l.note ?? '').isEmpty)
                    const TextSpan(text: '\n   (bỏ ghi chú)', style: TextStyle(fontStyle: FontStyle.italic)),
                ])),
              ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('MÓN MỚI', slip.send, theme.colorScheme.primary),
        section('ĐỔI GHI CHÚ', slip.changed, theme.colorScheme.tertiary, showOld: true),
        section('HỦY', slip.cancel, theme.colorScheme.error),
        if ((slip.orderNote ?? '').isNotEmpty) Text('Ghi chú đơn: ${slip.orderNote}'),
      ],
    );
  }
}

/// Lịch sử báo bếp của đơn — mỗi lần một thẻ (giờ, người báo, các món), in lại được.
Future<void> showKitchenHistory(BuildContext context, Order order) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _KitchenHistory(order: order, scroll: scroll),
    ),
  );
}

class _KitchenHistory extends ConsumerWidget {
  const _KitchenHistory({required this.order, required this.scroll});

  final Order order;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(kitchenHistoryProvider(order.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text('Lịch sử báo bếp — ${order.tableName}', style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(kitchenHistoryProvider(order.id)),
              ),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
            data: (history) => history.isEmpty
                ? const Center(child: Text('Đơn này chưa báo bếp lần nào.'))
                : ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final slip = history[i];
                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${formatDateTime(slip.createdAt)} · ${slip.staff ?? ''}',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  PrintButton(
                                    what: 'phiếu bếp',
                                    label: 'In lại',
                                    onPrint: () => ref.read(printActionsProvider).kitchen(slip, order),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              KitchenSlipView(slip: slip),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
