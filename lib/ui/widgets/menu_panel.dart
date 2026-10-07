import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/pos.dart';
import '../layout.dart';

/// Thực đơn để gọi món: tìm kiếm (không cần dấu), lọc danh mục, bấm món để thêm 1,
/// nhấn giữ để chọn số lượng + ghi chú.
class MenuPanel extends ConsumerStatefulWidget {
  const MenuPanel({super.key, required this.detail, required this.onAdd, required this.onAddWithOptions});

  final OrderDetail detail;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onAddWithOptions;

  @override
  ConsumerState<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends ConsumerState<MenuPanel> {
  final _search = TextEditingController();
  int? _categoryId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
        final q = foldVietnamese(_query.trim());
        final products = <Product>[
          for (final c in categories)
            if (q.isNotEmpty || _categoryId == null || c.id == _categoryId)
              for (final p in c.products)
                if (q.isEmpty || foldVietnamese(p.name).contains(q) || p.sku.toLowerCase().contains(q)) p,
        ];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm món (vd: ca phe sua)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isEmpty)
              SizedBox(
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

    final placeholder = Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        _initials(product.name),
        style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          formatMoney(product.price),
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
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
                          border: Border.all(color: scheme.primary, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('×$qtyInOrder',
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
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
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }
}
