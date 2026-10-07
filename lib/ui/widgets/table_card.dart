import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';

/// Ô bàn trên sơ đồ — màu theo trạng thái, giống web (Trống / Đang phục vụ / Chờ thanh toán).
/// Nội dung canh giữa; ô nhỏ hoặc chữ hệ thống lớn thì tự thu nhỏ thay vì tràn.
class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.table, this.onTap, this.onLongPress});

  final PosTable table;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color bg, Color fg) = switch (table.status) {
      Status.available => (scheme.surfaceContainerLow, scheme.onSurface),
      Status.waitPayment => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      Status.paid => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.primary, scheme.onPrimary),
    };
    final order = table.order;
    final busy = order != null && !table.isAvailable;

    return Card(
      color: bg,
      elevation: table.isAvailable ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: table.isAvailable ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(table.isTakeaway ? Icons.takeout_dining : Icons.table_restaurant, size: 16, color: fg),
                          const SizedBox(width: 4),
                          Text(
                            table.name,
                            style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (busy) ...[
                        Text(
                          formatMoney(order.totalAmount),
                          style: theme.textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                        ),
                      ] else
                        Text(
                          table.isTakeaway ? 'Bấm để tạo đơn' : '${table.capacity} chỗ',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        Status.tableLabel(table.status),
                        style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if ((table.note ?? '').isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: Tooltip(message: table.note!, child: Icon(Icons.sticky_note_2_outlined, size: 14, color: fg)),
              ),
          ],
        ),
      ),
    );
  }
}
