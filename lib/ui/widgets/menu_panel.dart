import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/pos.dart';
import '../layout.dart';
import 'order_panel.dart' show pendingColor;

/// Thực đơn để gọi món: lọc danh mục, bấm món để thêm 1, nhấn giữ để chọn số lượng + ghi chú.
/// Ô tìm món nằm trên thanh tiêu đề của màn hình đơn (nút 🔍) — [query] là chữ đang tìm (không cần dấu).
class MenuPanel extends ConsumerStatefulWidget {
  const MenuPanel({
    super.key,
    required this.detail,
    required this.onAdd,
    required this.onAddWithOptions,
    this.query = '',
  });

  final OrderDetail detail;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onAddWithOptions;
  final String query;

  @override
  ConsumerState<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends ConsumerState<MenuPanel> {
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);
    final layout = Layout.of(context);

    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Không tải được thực đơn: $e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(menuProvider), child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (categories) {
        final q = foldVietnamese(widget.query.trim());
        final products = <Product>[
          for (final c in categories)
            if (q.isNotEmpty || _categoryId == null || c.id == _categoryId)
              for (final p in c.products)
                if (q.isEmpty || foldVietnamese(p.name).contains(q) || p.sku.toLowerCase().contains(q)) p,
        ];

        return Column(
          children: [
            if (q.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _CategoryChip(
                        label: 'Tất cả',
                        selected: _categoryId == null,
                        onTap: () => setState(() => _categoryId = null),
                      ),
                      for (final c in categories)
                        _CategoryChip(
                          label: c.name,
                          selected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(menuProvider.future),
                child: products.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Không tìm thấy món nào.')),
                      ])
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          padding: layout.pagePadding,
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: layout.productGrid(constraints.maxWidth),
                          itemCount: products.length,
                          itemBuilder: (context, i) {
                            final p = products[i];
                            return ProductTile(
                              product: p,
                              qtyInOrder: widget.detail.qtyOfProduct(p.id),
                              onTap: () => widget.onAdd(p),
                              onLongPress: () => widget.onAddWithOptions(p),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class ProductTile extends ConsumerWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.qtyInOrder,
    required this.onTap,
    required this.onLongPress,
  });

  final Product product;
  final int qtyInOrder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imageUrl = ref.watch(apiClientProvider).imageUrl(product.image);

    // Món chưa có ảnh: hình ly cà phê mặc định.
    final placeholder = Container(
      color: scheme.primaryContainer,
      alignment: const Alignment(0, -0.25), // chừa chỗ cho nhãn giá ở đáy ảnh
      child: FractionallySizedBox(
        heightFactor: 0.5,
        child: FittedBox(child: Icon(Icons.local_cafe_outlined, color: scheme.primary.withValues(alpha: 0.55))),
      ),
    );

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: qtyInOrder > 0 ? scheme.primary : scheme.outlineVariant, width: qtyInOrder > 0 ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ảnh món, giá canh giữa ở đáy ảnh, số lượng đã gọi ở góc phải.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl == null)
                    placeholder
                  else
                    Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          formatMoney(product.price),
                          style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                  if (qtyInOrder > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          border: Border.all(color: pendingColor, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('×$qtyInOrder',
                            style: theme.textTheme.labelMedium?.copyWith(color: pendingColor, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, height: 1.2),
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
