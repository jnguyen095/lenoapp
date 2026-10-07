import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';

/// "Món đã gọi": mỗi dòng đánh số 1, 2, 3… (giống web), − số lượng +, thành tiền và menu
/// Ghi chú / Hủy món. Đơn đã đóng chỉ xem, món đã hủy gạch ngang.
class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.detail,
    this.showPendingBadge = false,
    required this.onQty,
    required this.onNote,
    required this.onRemove,
  });

  final OrderDetail detail;

  /// Hiện "N chưa báo bếp" đầu danh sách (điện thoại; tablet hiện ở tiêu đề cột).
  final bool showPendingBadge;
  final void Function(OrderItem item, int qty) onQty;
  final ValueChanged<OrderItem> onNote;
  final ValueChanged<OrderItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = detail.order;

    final banners = <Widget>[
      if (showPendingBadge && detail.isActive && detail.pendingCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(alignment: Alignment.centerLeft, child: PendingBadge(count: detail.pendingCount)),
        ),
      if ((order.tableNote ?? '').isNotEmpty)
        _Banner(icon: Icons.table_restaurant, text: 'Ghi chú bàn: ${order.tableNote}'),
      if ((order.note ?? '').isNotEmpty) _Banner(icon: Icons.sticky_note_2_outlined, text: 'Ghi chú đơn: ${order.note}'),
    ];

    if (detail.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...banners,
          const SizedBox(height: 48),
          Icon(Icons.local_cafe_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            detail.isActive ? 'Chưa có món nào.\nChọn món từ thực đơn để thêm.' : 'Đơn không có món.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: detail.items.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 52),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: banners));
        }
        final item = detail.items[i - 1];
        return _ItemRow(
          index: i,
          item: item,
          editable: detail.isActive && !item.isCancelled,
          onQty: onQty,
          onNote: onNote,
          onRemove: onRemove,
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer))),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.index,
    required this.item,
    required this.editable,
    required this.onQty,
    required this.onNote,
    required this.onRemove,
  });

  final int index;
  final OrderItem item;
  final bool editable;
  final void Function(OrderItem item, int qty) onQty;
  final ValueChanged<OrderItem> onNote;
  final ValueChanged<OrderItem> onRemove;

  /// Dưới bề rộng này (điện thoại, cột hẹp) nút −/+ xuống dòng dưới để tên món đủ chỗ.
  static const _stackBelow = 440.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final struck = item.isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    final number = CircleAvatar(
      radius: 14,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Text('$index', style: theme.textTheme.labelMedium),
    );
    final name = Text(item.productName,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500).merge(struck));
    final note = (item.note ?? '').isEmpty
        ? null
        : Text(item.note!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.tertiary));
    final priceAndTag = Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          editable ? formatMoney(item.price) : '${item.qty} × ${formatMoney(item.price)}',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (item.isCancelled)
          _Tag(text: 'Đã hủy', color: scheme.error)
        else if (editable && item.pending)
          const _PendingTag(),
      ],
    );
    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove, onPressed: item.qty > 1 ? () => onQty(item, item.qty - 1) : null),
        SizedBox(width: 36, child: Text('${item.qty}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium)),
        _StepButton(icon: Icons.add, onPressed: () => onQty(item, item.qty + 1)),
      ],
    );
    final amount = Text(
      formatMoney(item.amount, withUnit: false),
      textAlign: TextAlign.right,
      style: theme.textTheme.titleSmall?.merge(struck),
    );
    final menu = editable
        ? PopupMenuButton<String>(
            tooltip: 'Thêm thao tác',
            onSelected: (v) => v == 'note' ? onNote(item) : onRemove(item),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'note',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_note), title: Text('Ghi chú')),
              ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text('Hủy món', style: TextStyle(color: scheme.error)),
                ),
              ),
            ],
          )
        : const SizedBox(width: 12);

    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < _stackBelow;

      if (stacked) {
        // Điện thoại: [số] Tên món ............ thành tiền [⋮]
        //                  ghi chú / giá · Chưa báo     − 2 +
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: number),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: name),
                        const SizedBox(width: 8),
                        Padding(padding: const EdgeInsets.only(top: 2), child: amount),
                      ],
                    ),
                    if (note != null) note,
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: priceAndTag),
                        if (editable) stepper,
                      ],
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            number,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, ?note, priceAndTag],
              ),
            ),
            if (editable) stepper,
            SizedBox(width: 84, child: amount),
            menu,
          ],
        ),
      );
    });
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

/// Tổng tiền + nút Báo bếp / Thanh toán — luôn hiện ở cuối màn hình đơn.
class OrderSummaryBar extends StatelessWidget {
  const OrderSummaryBar({
    super.key,
    required this.detail,
    required this.onNotify,
    required this.onPrintBill,
    required this.onPay,
  });

  final OrderDetail detail;
  final VoidCallback? onNotify;
  final VoidCallback? onPrintBill;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = detail.order;
    final p = detail.payment;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (order.vatAmount > 0 || order.discountAmount > 0) ...[
                _line(context, 'Tạm tính', formatMoney(order.subtotal)),
                if (order.discountAmount > 0) _line(context, 'Giảm giá', '-${formatMoney(order.discountAmount)}'),
                if (order.vatAmount > 0) _line(context, 'VAT', formatMoney(order.vatAmount)),
              ],
              Row(
                children: [
                  Text('Tổng (${detail.activeItemCount} món)', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatMoney(order.totalAmount),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (detail.isActive)
                // 3 nút cùng hàng như web: Báo bếp · Tạm tính · Thanh toán.
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Badge(
                          isLabelVisible: detail.pendingCount > 0,
                          label: Text('${detail.pendingCount}'),
                          child: const Icon(Icons.notifications_active_outlined),
                        ),
                        label: 'Báo bếp',
                        style: _ActionStyle.tonal,
                        onPressed: detail.pendingCount > 0 ? onNotify : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: const Icon(Icons.receipt_outlined),
                        label: 'Tạm tính',
                        style: _ActionStyle.outlined,
                        onPressed: detail.activeItemCount > 0 ? onPrintBill : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: const Icon(Icons.payments_outlined),
                        label: 'Thanh toán',
                        style: _ActionStyle.filled,
                        onPressed: detail.activeItemCount > 0 ? onPay : null,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(order.status == Status.paid ? Icons.check_circle : Icons.cancel_outlined,
                        color: order.status == Status.paid ? theme.colorScheme.primary : theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p == null
                            ? Status.orderLabel(order.status)
                            : '${Status.orderLabel(order.status)} · ${p.methodLabel} · ${formatTime(p.paidAt)}',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [Text(label), const Spacer(), Text(value)]),
      );
}

enum _ActionStyle { tonal, outlined, filled }

/// Nút lớn: biểu tượng trên, chữ dưới — 3 nút vừa một hàng kể cả trên điện thoại.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.style, required this.onPressed});

  final Widget icon;
  final String label;
  final _ActionStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)],
    );
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
    const size = Size.fromHeight(58);
    const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    return switch (style) {
      _ActionStyle.tonal => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: size, padding: padding, shape: shape),
          child: child,
        ),
      _ActionStyle.outlined => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: size, padding: padding, shape: shape),
          child: child,
        ),
      _ActionStyle.filled => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: size, padding: padding, shape: shape),
          child: child,
        ),
    };
  }
}

/// Màu nổi cho phần chưa báo bếp (cam) — dễ thấy trên nền xanh của ứng dụng.
const pendingColor = Color(0xFFEF6C00);

/// Huy hiệu "N chưa báo bếp".
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: pendingColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count chưa báo bếp',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Nhãn "Chưa báo" trên dòng món — nền cam chữ trắng.
class _PendingTag extends StatelessWidget {
  const _PendingTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: pendingColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        'Chưa báo',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
