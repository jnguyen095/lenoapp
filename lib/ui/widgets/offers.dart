import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import 'dialogs.dart';
import 'top_toast.dart';

/// Sơ đồ bàn — 2 nút trên thanh tiêu đề: Bảng giá và Khuyến mãi (giống web về cách áp): chọn ở đây áp ngay cho
/// MỌI đơn đang mở (chưa thanh toán) và bàn mở sau, dùng chung mọi máy. Trang đơn chỉ bỏ được cho riêng đơn đó
/// ([OrderOfferChips]). Nút tô màu khi đang áp; bấm để mở danh sách chọn. Ẩn khi hôm nay không có gì để chọn.
class ShopOffersActions extends ConsumerStatefulWidget {
  const ShopOffersActions({super.key, required this.onApplied});

  /// Đã áp xong (tiền trên các bàn đổi) -> làm mới sơ đồ bàn.
  final VoidCallback onApplied;

  @override
  ConsumerState<ShopOffersActions> createState() => _ShopOffersActionsState();
}

class _ShopOffersActionsState extends ConsumerState<ShopOffersActions> {
  bool _saving = false;

  Future<void> _apply({int? priceBookId, int? discountId}) async {
    setState(() => _saving = true);
    try {
      final count = await ref.read(shopOffersProvider.notifier).apply(priceBookId: priceBookId, discountId: discountId);
      if (!mounted) return;
      showTopToast(context, count > 0 ? 'Đã áp dụng cho $count đơn đang mở.' : 'Đã lưu — áp dụng cho bàn mở sau.');
      widget.onApplied();
    } catch (e) {
      // Lỗi (vd vừa hết hiệu lực): giữ lựa chọn cũ, tải lại danh sách.
      if (mounted) showError(context, e);
      ref.invalidate(shopOffersProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(shopOffersProvider).valueOrNull;
    if (offers == null || !offers.isRelevant) return const SizedBox.shrink();
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final bookId = offers.priceBookId;
    final discount = offers.discount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OfferAction(
          icon: Icons.sell_outlined,
          activeIcon: Icons.sell,
          title: 'Bảng giá',
          current: offers.priceBookName,
          noneLabel: 'Giá gốc',
          emptyLabel: 'Không có bảng giá hôm nay',
          options: [for (final b in offers.priceBooks) (b.id, b.name, null)],
          selected: bookId,
          onSelected: (id) => _apply(priceBookId: id, discountId: discount?.id),
        ),
        _OfferAction(
          icon: Icons.percent,
          activeIcon: Icons.percent,
          title: 'Khuyến mãi',
          current: discount?.name,
          noneLabel: 'Không áp dụng',
          emptyLabel: 'Không có khuyến mãi hôm nay',
          // Mô tả đầy đủ dưới tên, vd "Giảm 15% (tối đa 50.000) · đơn từ 500.000".
          options: [for (final d in offers.discounts) (d.id, d.name, d.description)],
          selected: discount?.id,
          onSelected: (id) => _apply(priceBookId: bookId, discountId: id),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Một nút trên thanh tiêu đề: biểu tượng (tô nền màu chính + chấm khi đang áp), bấm mở danh sách chọn.
/// Màn hình rộng hiện thêm tên đang chọn cạnh biểu tượng.
class _OfferAction extends StatelessWidget {
  const _OfferAction({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.current,
    required this.noneLabel,
    required this.emptyLabel,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// Giá trị "không áp dụng" trong menu (PopupMenuButton coi null là bấm ra ngoài).
  static const _none = 0;

  final IconData icon;
  final IconData activeIcon;
  final String title;

  /// Tên đang chọn (null = không áp dụng).
  final String? current;
  final String noneLabel;
  final String emptyLabel;

  /// (id, tên, mô tả).
  final List<(int, String, String?)> options;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = selected != null;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    Widget check(bool v) => SizedBox(
          width: 24,
          child: v ? Icon(Icons.check, size: 20, color: scheme.primary) : null,
        );

    return PopupMenuButton<int>(
      tooltip: on ? '$title: $current' : '$title: $noneLabel',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
      onSelected: (v) {
        final id = v == _none ? null : v;
        if (id != selected) onSelected(id);
      },
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          height: 36,
          child: Text(title.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.outline, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        PopupMenuItem<int>(
          value: _none,
          enabled: options.isNotEmpty || on,
          child: Row(children: [
            check(!on),
            const SizedBox(width: 8),
            Text(options.isNotEmpty || on ? noneLabel : emptyLabel),
          ]),
        ),
        for (final (id, name, desc) in options)
          PopupMenuItem<int>(
            value: id,
            child: Row(children: [
              check(id == selected),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        style: id == selected ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600) : null),
                    if (desc != null && desc.isNotEmpty)
                      Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          enabled: false,
          child: Text(
            'Áp dụng cho mọi bàn đang phục vụ (chưa thanh toán) và bàn mở sau. Trang đơn có thể bỏ cho từng đơn.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
      ],
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: wide && on ? 12 : 8),
        decoration: BoxDecoration(
          color: on ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(20),
          border: on ? Border.all(color: scheme.primary.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: on && !wide,
              smallSize: 8,
              backgroundColor: Colors.green.shade600,
              child: Icon(on ? activeIcon : icon, size: 22, color: on ? scheme.primary : scheme.onSurfaceVariant),
            ),
            // Màn hình rộng: tên đang chọn cạnh biểu tượng để thu ngân nhìn là biết.
            if (wide && on) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(current ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trang đơn — bảng giá / khuyến mãi của đơn (chọn ở Sơ đồ bàn) dạng thẻ, ✕ để bỏ cho riêng đơn này (giống web).
/// Chỉ hiện khi đơn có bảng giá hoặc khuyến mãi.
class OrderOfferChips extends ConsumerWidget {
  const OrderOfferChips({
    super.key,
    required this.order,
    required this.active,
    required this.editable,
    required this.onRemovePriceBook,
    required this.onRemoveDiscount,
    required this.onReapplyPriceBook,
    required this.onReapplyDiscount,
  });

  final Order order;

  /// Đơn đang mở (đơn đã đóng chỉ xem, không gợi ý áp lại).
  final bool active;

  /// Đơn đang mở và không bận -> hiện nút ✕ / ↻.
  final bool editable;
  final VoidCallback onRemovePriceBook;
  final VoidCallback onRemoveDiscount;

  /// Áp lại lựa chọn đang có ở Sơ đồ bàn (id) cho đơn đã bỏ.
  final ValueChanged<int> onReapplyPriceBook;
  final ValueChanged<int> onReapplyDiscount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBook = order.priceBookId != null || (order.priceBookName ?? '').isNotEmpty;
    final hasDisc = order.hasDiscount;
    // Đơn đã bỏ mà Sơ đồ bàn đang chọn -> cho áp lại (chỉ đơn đang mở).
    final shop = active ? ref.watch(shopOffersProvider).valueOrNull : null;
    final reBookId = !hasBook ? shop?.priceBookId : null;
    final reDiscount = !hasDisc ? shop?.discount : null;
    if (!hasBook && !hasDisc && reBookId == null && reDiscount == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final shortOf = order.discountShortOf;

    // Hàng hẹp (điện thoại): mỗi ô chưa tới ~200px -> ghi chú xuống dòng riêng.
    final stacked = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _OfferChip(
                icon: Icons.sell_outlined,
                stacked: stacked,
                label: 'Bảng giá',
                value: hasBook ? (order.priceBookName ?? 'Bảng giá') : 'Giá gốc',
                tone: hasBook ? _ChipTone.on : _ChipTone.none,
                note: !hasBook && reBookId != null ? 'Đã bỏ: ${shop!.priceBookName ?? ''}' : null,
                onReapply: !hasBook && reBookId != null && editable ? () => onReapplyPriceBook(reBookId) : null,
                onRemove: hasBook && editable
                    ? () async {
                        if (await confirmDialog(context,
                            title: 'Bỏ bảng giá — đơn này tính theo giá gốc?', confirmLabel: 'Bỏ', destructive: true)) {
                          onRemovePriceBook();
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OfferChip(
                icon: Icons.percent,
                label: 'Khuyến mãi',
                stacked: stacked,
                value: hasDisc ? (order.discountName ?? 'Khuyến mãi') : 'Không áp dụng',
                // Chưa đủ đơn tối thiểu: còn thiếu bao nhiêu; đủ rồi: đã giảm bao nhiêu.
                note: !hasDisc
                    ? (reDiscount != null ? 'Đã bỏ: ${reDiscount.name}' : null)
                    : shortOf > 0
                        ? 'Mua thêm ${formatMoney(shortOf)} để được giảm'
                        : 'Đã giảm ${formatMoney(order.discountAmount)}',
                tone: !hasDisc ? _ChipTone.none : (shortOf > 0 ? _ChipTone.wait : _ChipTone.discount),
                onReapply: reDiscount != null && editable ? () => onReapplyDiscount(reDiscount.id) : null,
                onRemove: hasDisc && editable
                    ? () async {
                        if (await confirmDialog(context,
                            title: 'Bỏ khuyến mãi cho đơn này?', confirmLabel: 'Bỏ', destructive: true)) {
                          onRemoveDiscount();
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChipTone { none, on, discount, wait }

class _OfferChip extends StatelessWidget {
  const _OfferChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.note,
    this.onRemove,
    this.onReapply,
    this.stacked = false,
  });

  /// Ô hẹp (điện thoại): ghi chú xuống dòng riêng dưới tên.
  final bool stacked;

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final _ChipTone tone;
  final VoidCallback? onRemove;

  /// Đơn đã bỏ, Sơ đồ bàn đang chọn -> nút ↻ áp lại.
  final VoidCallback? onReapply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color accent, Color border, Color bg) = switch (tone) {
      _ChipTone.none => (scheme.outline, scheme.outlineVariant, scheme.surface),
      _ChipTone.on => (scheme.primary, scheme.primary, scheme.primaryContainer.withValues(alpha: 0.35)),
      _ChipTone.discount => (Colors.green.shade700, Colors.green.shade600, Colors.green.shade50),
      _ChipTone.wait => (Colors.orange.shade800, Colors.orange.shade300, Colors.orange.shade50),
    };

    // Gọn một hàng: biểu tượng · tên (đậm) + ghi chú nhỏ ngay sau, nút ✕ / ↻ nhỏ ở cuối. Tên mục (Bảng giá /
    // Khuyến mãi) nằm trong gợi ý khi nhấn giữ.
    final valueColor = tone == _ChipTone.none ? scheme.outline : accent;
    return Tooltip(
      message: note == null ? '$label: $value' : '$label: $value · $note',
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tone == _ChipTone.none ? scheme.outlineVariant : accent),
            const SizedBox(width: 6),
            Expanded(
              child: Builder(builder: (context) {
                final valueStyle = theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: tone == _ChipTone.none ? FontWeight.w500 : FontWeight.w600,
                );
                final noteStyle = theme.textTheme.labelSmall?.copyWith(color: accent);
                // Ô hẹp (điện thoại): tên một dòng, ghi chú xuống dòng riêng để không bị cắt mất số tiền.
                if (note != null && stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle),
                      Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: noteStyle),
                    ],
                  );
                }
                // Ô rộng: tên + ghi chú nhỏ ngay sau trên cùng một dòng.
                return Text.rich(
                  TextSpan(children: [
                    TextSpan(text: value, style: valueStyle),
                    if (note != null) TextSpan(text: '  $note', style: noteStyle),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ),
            if (onRemove != null || onReapply != null)
              SizedBox.square(
                dimension: 28,
                child: IconButton(
                  onPressed: onRemove ?? onReapply,
                  tooltip: onRemove != null ? 'Bỏ cho đơn này' : 'Áp dụng lại cho đơn này',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        onRemove != null ? Colors.black.withValues(alpha: 0.05) : scheme.primaryContainer,
                    foregroundColor: onRemove != null ? null : scheme.primary,
                  ),
                  iconSize: 16,
                  icon: Icon(onRemove != null ? Icons.close : Icons.replay),
                ),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
