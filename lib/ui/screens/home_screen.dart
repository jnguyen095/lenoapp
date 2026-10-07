import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import '../layout.dart';
import '../widgets/dialogs.dart';
import '../widgets/table_card.dart';
import 'order_screen.dart';
import 'printer_settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    if (session == null) return const Scaffold(); // đang chuyển về màn hình đăng nhập
    final user = session.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.canTables ? 'Sơ đồ bàn' : 'Đơn đang phục vụ'),
            // Tên quán trong Cài đặt máy in (giống dòng đầu hóa đơn), sửa được ngay trên máy.
            Text(
              ref.watch(printSettingsProvider).valueOrNull?.shopName ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: CircleAvatar(
              radius: 16,
              child: Text(user.fullname.isEmpty ? '?' : user.fullname.characters.first.toUpperCase()),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(user.fullname),
                  subtitle: Text('${user.roleLabel}\n${session.serverUrl}'),
                  isThreeLine: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'printers',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.print_outlined), title: Text('Cài đặt máy in')),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Đăng xuất')),
              ),
            ],
            onSelected: (value) async {
              if (value == 'printers') {
                await Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()));
                return;
              }
              if (value == 'logout' &&
                  await confirmDialog(context, title: 'Đăng xuất khỏi máy này?', confirmLabel: 'Đăng xuất')) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user.canTables ? _TableMap(canOrder: user.canOrders) : const _ActiveOrders(),
    );
  }
}

enum _TableFilter { all, free, busy }

class _TableMap extends ConsumerStatefulWidget {
  const _TableMap({required this.canOrder});

  final bool canOrder;

  @override
  ConsumerState<_TableMap> createState() => _TableMapState();
}

class _TableMapState extends ConsumerState<_TableMap> {
  _TableFilter _filter = _TableFilter.all;
  bool _busy = false;

  TablesController get _tables => ref.read(tablesProvider.notifier);

  Future<void> _openOrder(int orderId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: orderId)));
    _tables.refreshSilently();
  }

  Future<void> _onTap(PosTable table) async {
    if (!widget.canOrder) {
      showMessage(context, 'Tài khoản của bạn không có quyền gọi món. Nhấn giữ bàn để chuyển/gộp bàn.');
      return;
    }
    if (!table.isAvailable) {
      final order = table.order;
      if (order != null) {
        await _openOrder(order.id);
      } else {
        showMessage(context, 'Bàn này đang ở trạng thái lỗi — nhờ quản lý "Đặt lại trạng thái" trên web.');
        _tables.refreshSilently();
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final detail = await _tables.openTable(table);
      if (mounted) await _openOrder(detail.order.id);
    } catch (e) {
      if (mounted) showError(context, e);
      _tables.refreshSilently();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLongPress(PosTable table, List<PosTable> all) async {
    if (table.isAvailable || table.order == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(table.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${table.order!.orderNo} · ${formatMoney(table.order!.totalAmount)}'),
            ),
            if (widget.canOrder)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Mở đơn'),
                onTap: () => Navigator.pop(context, 'open'),
              ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Chuyển bàn'),
              subtitle: const Text('Chuyển khách sang một bàn trống'),
              onTap: () => Navigator.pop(context, 'transfer'),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('Gộp bàn'),
              subtitle: const Text('Gộp đơn của bàn này vào bàn khác đang phục vụ'),
              onTap: () => Navigator.pop(context, 'merge'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'open':
        await _openOrder(table.order!.id);
      case 'transfer':
        await _transfer(table, all);
      case 'merge':
        await _merge(table, all);
    }
  }

  Future<void> _transfer(PosTable from, List<PosTable> all) async {
    // Giống web: chỉ bàn thường đang trống (không gồm bàn Mang đi).
    final targets = all.where((t) => t.isAvailable && !t.isTakeaway && t.id != from.id).toList();
    final target = await showPickerDialog<PosTable>(
      context,
      title: 'Chuyển ${from.name} sang…',
      options: targets,
      label: (t) => t.name,
      subtitle: (t) => '${t.capacity} chỗ',
      emptyText: 'Không còn bàn trống.',
    );
    if (target == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _tables.transfer(from, target);
      if (mounted) showMessage(context, 'Đã chuyển ${from.name} sang ${target.name}.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge(PosTable from, List<PosTable> all) async {
    final targets = all.where((t) => !t.isAvailable && t.order != null && !t.isTakeaway && t.id != from.id).toList();
    final target = await showPickerDialog<PosTable>(
      context,
      title: 'Gộp ${from.name} vào…',
      options: targets,
      label: (t) => t.name,
      subtitle: (t) => formatMoney(t.order!.totalAmount),
      emptyText: 'Không có bàn nào khác đang phục vụ.',
    );
    if (target == null || !mounted) return;
    if (!await confirmDialog(context,
        title: 'Gộp ${from.name} vào ${target.name}?',
        message: 'Toàn bộ món của ${from.name} sẽ chuyển sang đơn của ${target.name}, ${from.name} trở về Trống.',
        confirmLabel: 'Gộp bàn')) {
      return;
    }

    setState(() => _busy = true);
    try {
      final detail = await _tables.merge(from, target);
      if (mounted && widget.canOrder) await _openOrder(detail.order.id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final layout = Layout.of(context);

    return tablesAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(error: e, onRetry: () => _tables.refresh()),
      data: (tables) {
        final free = tables.where((t) => t.isAvailable).length;
        final shown = switch (_filter) {
          _TableFilter.all => tables,
          _TableFilter.free => tables.where((t) => t.isAvailable).toList(),
          _TableFilter.busy => tables.where((t) => !t.isAvailable).toList(),
        };

        return Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_TableFilter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: _TableFilter.all, label: Text('Tất cả (${tables.length})')),
                    ButtonSegment(value: _TableFilter.free, label: Text('Trống ($free)')),
                    ButtonSegment(value: _TableFilter.busy, label: Text('Có khách (${tables.length - free})')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _tables.refresh,
                child: shown.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Không có bàn nào.')),
                      ])
                    : GridView.builder(
                        padding: layout.pagePadding,
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate: layout.tableGrid,
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final t = shown[i];
                          return TableCard(
                            table: t,
                            onTap: _busy ? null : () => _onTap(t),
                            onLongPress: _busy ? null : () => _onLongPress(t, tables),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Cho tài khoản chỉ có quyền Đơn hàng: danh sách đơn đang phục vụ.
class _ActiveOrders extends ConsumerWidget {
  const _ActiveOrders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(activeOrdersProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(activeOrdersProvider)),
          data: (orders) {
            final withItems = orders.where((o) => (o.itemCount ?? 0) > 0).toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(activeOrdersProvider.future),
              child: withItems.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Không có đơn nào đang phục vụ.')),
                    ])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: withItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final o = withItems[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(o.tableName ?? 'Mang đi'),
                          subtitle: Text('${o.orderNo} · ${o.itemCount} món · ${Status.orderLabel(o.status)}'),
                          trailing: Text(formatMoney(o.totalAmount), style: Theme.of(context).textTheme.titleMedium),
                          onTap: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: o.id)));
                            ref.invalidate(activeOrdersProvider);
                          },
                        );
                      },
                    ),
            );
          },
        );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
