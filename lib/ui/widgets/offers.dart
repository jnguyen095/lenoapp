import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import 'dialogs.dart';
import 'top_toast.dart';

/// Sơ đồ bàn — hàng "Bảng giá | Khuyến mãi" (giống web): chọn ở đây áp ngay cho MỌI đơn đang mở (chưa thanh toán)
/// và bàn mở sau, dùng chung mọi máy. Trang đơn chỉ bỏ được cho riêng đơn đó ([OrderOfferChips]).
/// Ẩn khi hôm nay không có bảng giá / khuyến mãi nào và cũng không đang chọn.
class ShopOffersBar extends ConsumerStatefulWidget {
  const ShopOffersBar({super.key, required this.onApplied});

  /// Đã áp xong (tiền trên các bàn đổi) -> làm mới sơ đồ bàn.
  final VoidCallback onApplied;

  @override
  ConsumerState<ShopOffersBar> createState() => _ShopOffersBarState();
}

class _ShopOffersBarState extends ConsumerState<ShopOffersBar> {
  bool _saving = false;

  Future<void> _apply(ShopOffers cur, {int? priceBookId, int? discountId}) async {
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final books = offers.priceBooks;
    final discounts = offers.discounts;
    final bookId = offers.priceBookId;
    final discount = offers.discount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OfferSelect(
                  icon: Icons.sell_outlined,
                  label: 'Bảng giá',
                  on: bookId != null,
                  value: bookId,
                  enabled: !_saving && books.isNotEmpty,
                  onChanged: (v) {
                    if (v != bookId) _apply(offers, priceBookId: v, discountId: discount?.id);
                  },
                  options: [
                    (null, books.isNotEmpty ? 'Giá gốc' : 'Không có bảng giá hôm nay'),
                    for (final b in books) (b.id, b.name),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OfferSelect(
                  icon: Icons.percent,
                  label: 'Khuyến mãi',
                  on: discount != null,
                  value: discount?.id,
                  enabled: !_saving && discounts.isNotEmpty,
                  onChanged: (v) {
                    if (v != discount?.id) _apply(offers, priceBookId: bookId, discountId: v);
                  },
                  options: [
                    (null, discounts.isNotEmpty ? 'Không áp dụng' : 'Không có khuyến mãi hôm nay'),
                    for (final d in discounts) (d.id, d.name),
                  ],
                  // Trong danh sách: mô tả đầy đủ dưới tên, vd "Giảm 15% (tối đa 50.000) · đơn từ 500.000".
                  details: {for (final d in discounts) d.id: d.description},
                  hint: discount == null ? null : (Icons.info_outline, discount.description),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_saving)
                const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
              else
                Icon(Icons.info_outline, size: 14, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Áp dụng cho mọi bàn đang phục vụ (chưa thanh toán) và bàn mở sau. Trang đơn có thể bỏ cho từng đơn.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Trang đơn — bảng giá / khuyến mãi của đơn (chọn ở Sơ đồ bàn) dạng thẻ, ✕ để bỏ cho riêng đơn này (giống web).
/// Chỉ hiện khi đơn có bảng giá hoặc khuyến mãi.
class OrderOfferChips extends StatelessWidget {
  const OrderOfferChips({
    super.key,
    required this.order,
    required this.editable,
    required this.onRemovePriceBook,
    required this.onRemoveDiscount,
  });

  final Order order;

  /// Đơn đang mở và không bận -> hiện nút ✕.
  final bool editable;
  final VoidCallback onRemovePriceBook;
  final VoidCallback onRemoveDiscount;

  @override
  Widget build(BuildContext context) {
    final hasBook = order.priceBookId != null || (order.priceBookName ?? '').isNotEmpty;
    final hasDisc = order.hasDiscount;
    if (!hasBook && !hasDisc) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final shortOf = order.discountShortOf;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _OfferChip(
                icon: Icons.sell_outlined,
                label: 'Bảng giá',
                value: hasBook ? (order.priceBookName ?? 'Bảng giá') : 'Giá gốc',
                tone: hasBook ? _ChipTone.on : _ChipTone.none,
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
                value: hasDisc ? (order.discountName ?? 'Khuyến mãi') : 'Không áp dụng',
                // Chưa đủ đơn tối thiểu: còn thiếu bao nhiêu; đủ rồi: đã giảm bao nhiêu.
                note: !hasDisc
                    ? null
                    : shortOf > 0
                        ? 'Mua thêm ${formatMoney(shortOf)} để được giảm'
                        : 'Đã giảm ${formatMoney(order.discountAmount)}',
                tone: !hasDisc ? _ChipTone.none : (shortOf > 0 ? _ChipTone.wait : _ChipTone.discount),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final _ChipTone tone;
  final VoidCallback? onRemove;

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

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone == _ChipTone.none ? scheme.outlineVariant : accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label.toUpperCase(),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.outline, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tone == _ChipTone.none ? scheme.outline : accent,
                    fontWeight: tone == _ChipTone.none ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
                if (note != null)
                  Text(note!, style: theme.textTheme.labelSmall?.copyWith(color: accent)),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Bỏ cho đơn này',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.05)),
              iconSize: 16,
              icon: const Icon(Icons.close),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Một ô chọn trong [ShopOffersBar]: nhãn nhỏ phía trên, ô chọn có viền (tô màu khi đang áp), dòng gợi ý tuỳ chọn.
class _OfferSelect extends StatelessWidget {
  const _OfferSelect({
    required this.icon,
    required this.label,
    required this.on,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
    this.details = const {},
    this.hint,
  });

  final IconData icon;
  final String label;

  /// Đang chọn (tô màu chính).
  final bool on;
  final int? value;

  /// (giá trị, tên hiển thị); null = không áp dụng.
  final List<(int?, String)> options;

  /// Dòng mô tả nhỏ dưới tên trong danh sách thả xuống.
  final Map<int, String> details;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final (IconData, String)? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = on ? scheme.primary : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: accent)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: on ? scheme.primaryContainer.withValues(alpha: 0.45) : scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? accent.withValues(alpha: 0.6) : scheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: value,
              onChanged: enabled ? onChanged : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? accent : scheme.onSurface,
              ),
              // Ô đang chọn: một dòng, cắt "..." khi dài.
              selectedItemBuilder: (context) => [
                for (final (_, name) in options)
                  Align(alignment: Alignment.centerLeft, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              items: [
                for (final (id, name) in options)
                  DropdownMenuItem<int?>(
                    value: id,
                    child: details[id] == null || details[id]!.isEmpty
                        ? Text(name)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(details[id]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(hint!.$1, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(hint!.$2,
                    maxLines: 2, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
