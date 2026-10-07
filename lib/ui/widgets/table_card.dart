import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';

/// Ô bàn trên sơ đồ — màu theo trạng thái, giống web (Trống / Đang phục vụ / Chờ thanh toán).
/// Chỉ hiện tên bàn và tổng tiền (khi có khách), canh giữa; trạng thái phân biệt bằng màu ô.
/// Ô nhỏ hoặc chữ hệ thống lớn thì tự thu nhỏ thay vì tràn.
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
                      // Chỉ tên bàn (to, chữ thường) + tổng tiền khi có khách — trạng thái nhìn theo màu ô; chỉ bàn Mang đi có biểu tượng.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (table.isTakeaway) ...[
                            Icon(Icons.takeout_dining, size: 20, color: fg),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            table.name,
                            style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      if (busy) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatMoney(order.totalAmount),
                          style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
