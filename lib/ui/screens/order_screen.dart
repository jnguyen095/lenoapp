import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import '../layout.dart';
import '../widgets/dialogs.dart';
import '../widgets/menu_panel.dart';
import '../widgets/order_panel.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/kitchen_history_sheet.dart';
import '../widgets/print_feedback.dart';
import '../widgets/top_toast.dart';

/// Màn hình gọi món của một đơn (web: tab "Thực đơn" — /me/orders/{id}).
/// Tablet ngang: thực đơn bên trái, món đã gọi bên phải. Điện thoại: 2 tab.
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int _busy = 0;

  OrderController get _order => ref.read(orderProvider(widget.orderId).notifier);

  /// Chạy một thao tác: hiện thanh tiến trình, lỗi thì báo; đơn đã bị đóng ở máy khác thì tải lại.
  Future<T?> _act<T>(Future<T> Function() action) async {
    setState(() => _busy++);
    try {
      return await action();
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
      if (e.statusCode == 409 || e.statusCode == 404) await _order.refresh();
      return null;
    } catch (e) {
      if (mounted) showError(context, e);
      return null;
    } finally {
      if (mounted) setState(() => _busy--);
    }
  }

  void _add(Product p) => _act(() => _order.addProduct(p));

  Future<void> _addWithOptions(Product p) async {
    final result = await showAddProductDialog(context, p);
    if (result == null) return;
    await _act(() => _order.addProduct(p, qty: result.qty, note: result.note));
  }

  void _setQty(OrderItem item, int qty) => _act(() => _order.setQty(item, qty));

  Future<void> _editItemNote(OrderItem item) async {
    final note = await showNoteDialog(context, title: 'Ghi chú — ${item.productName}', initial: item.note);
    if (note == null || note == (item.note ?? '')) return;
    await _act(() => _order.setItemNote(item, note.isEmpty ? null : note));
  }

  Future<void> _removeItem(OrderItem item) async {
    if (item.notifiedQty > 0 &&
        !await confirmDialog(
          context,
          title: 'Hủy ${item.productName}?',
          message: 'Món này đã báo bếp. Lần "Báo bếp" tới sẽ gửi phiếu HỦY cho bếp.',
          confirmLabel: 'Hủy món',
          destructive: true,
        )) {
      return;
    }
    await _act(() => _order.removeItem(item));
  }

  Future<void> _editOrderNote(Order order) async {
    final note = await showNoteDialog(context, title: 'Ghi chú cho cả đơn', initial: order.note, quick: false);
    if (note == null || note == (order.note ?? '')) return;
    await _act(() => _order.setNote(note.isEmpty ? null : note));
  }

  Future<void> _notifyKitchen() async {
    final detail = await _act(_order.notifyKitchen);
    final slip = detail?.kitchenSlip;
    if (slip == null || !mounted) return;
    ref.invalidate(kitchenHistoryProvider(widget.orderId));

    final order = detail!.order;
    final summary = [
      if (slip.send.isNotEmpty) '${slip.send.fold<int>(0, (s, l) => s + l.qty)} món mới',
      if (slip.cancel.isNotEmpty) '${slip.cancel.fold<int>(0, (s, l) => s + l.qty)} món hủy',
      if (slip.changed.isNotEmpty) '${slip.changed.length} đổi ghi chú',
    ].join(', ');
    Future<PrintReport> printSlip() => ref.read(printActionsProvider).kitchen(slip, order);
    // Thông báo ở đầu màn hình, tự ẩn; bấm vào để xem lịch sử báo bếp (cũng mở được bằng nút ⏱ trên thanh tiêu đề).
    void toast(String message) => showTopToast(context, message,
        actionLabel: 'Lịch sử', onTap: () => showKitchenHistory(context, order));

    toast('Đã báo bếp: $summary');

    final settings = await ref.read(printSettingsProvider.future);
    if (!settings.autoPrintKitchen || !mounted) return;
    final report = await printSlip();
    if (!mounted) return;
    if (report.ok && report.printed > 0 && report.warnings.isEmpty) {
      toast('Đã báo bếp: $summary · đã in ${report.printed} phiếu');
    }
    showPrintReport(context, report, what: 'phiếu bếp', retry: printSlip, quietWhenNotConfigured: true);
  }

  /// In tạm tính (đơn đang mở) hoặc in lại hóa đơn (đơn đã thanh toán).
  Future<void> _printBill(OrderDetail detail) async {
    final what = detail.isActive ? 'phiếu tạm tính' : 'hóa đơn';
    Future<PrintReport> run() => ref.read(printActionsProvider).bill(detail);
    setState(() => _busy++);
    final report = await run();
    if (!mounted) return;
    setState(() => _busy--);
    if (report.ok && report.printed > 0) showMessage(context, 'Đã in $what.');
    showPrintReport(context, report, what: what, retry: run);
  }

  Future<void> _pay(OrderDetail detail) async {
    if (detail.pendingCount > 0 &&
        !await confirmDialog(
          context,
          title: 'Còn ${detail.pendingCount} món chưa báo bếp',
          message: 'Bếp chưa nhận các món này. Vẫn thanh toán?',
          confirmLabel: 'Vẫn thanh toán',
        )) {
      return;
    }
    if (!mounted) return;

    // Lấy tổng mới nhất trước khi thu tiền (web/máy khác có thể vừa sửa đơn).
    await _order.refresh();
    if (!mounted) return;
    final latest = ref.read(orderProvider(widget.orderId)).valueOrNull ?? detail;
    if (!latest.isActive) {
      showMessage(context, 'Đơn này đã được đóng ở máy khác.');
      return;
    }

    final input = await showPaymentSheet(context, total: latest.order.totalAmount, title: latest.order.tableName);
    if (input == null || !mounted) return;

    final paid = await _act(() => _order.pay(input.method, receivedAmount: input.received));
    if (paid == null || !mounted) return;

    Future<PrintReport> printReceipt() => ref.read(printActionsProvider).bill(paid);
    final settings = await ref.read(printSettingsProvider.future);
    if (settings.autoPrintReceipt) {
      final report = await printReceipt();
      if (mounted) showPrintReport(context, report, what: 'hóa đơn', retry: printReceipt, quietWhenNotConfigured: true);
    }
    if (!mounted) return;
    await showReceiptDialog(context, paid, onPrint: printReceipt);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    return orderAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(orderProvider(widget.orderId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: _buildOrder,
    );
  }

  Widget _buildOrder(OrderDetail detail) {
    final order = detail.order;
    final theme = Theme.of(context);
    final layout = Layout.of(context);
    final wide = layout.splitOrder;
    final showMenu = detail.isActive;

    final progress = PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: _busy > 0 ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
    );

    final orderPanel = RefreshIndicator(
      onRefresh: _order.refresh,
      child: OrderPanel(
        detail: detail,
        showPendingBadge: !wide,
        onQty: _setQty,
        onNote: _editItemNote,
        onRemove: _removeItem,
      ),
    );
    final summary = OrderSummaryBar(
      detail: detail,
      onNotify: _busy > 0 ? null : _notifyKitchen,
      onPrintBill: _busy > 0 ? null : () => _printBill(detail),
      onPay: _busy > 0 ? null : () => _pay(detail),
    );
    final menu = MenuPanel(detail: detail, onAdd: _add, onAddWithOptions: _addWithOptions);

    final appBarTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(order.tableName),
        Text('${order.orderNo} · ${Status.orderLabel(order.status)}', style: theme.textTheme.bodySmall),
      ],
    );
    final actions = [
      if (detail.isActive)
        IconButton(
          tooltip: 'Ghi chú đơn',
          icon: Icon((order.note ?? '').isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2),
          onPressed: () => _editOrderNote(order),
        ),
      IconButton(
        tooltip: 'Lịch sử báo bếp',
        icon: const Icon(Icons.history),
        onPressed: () => showKitchenHistory(context, order),
      ),
      if (order.status == Status.paid)
        IconButton(
          tooltip: 'In lại hóa đơn',
          icon: const Icon(Icons.print_outlined),
          onPressed: _busy > 0 ? null : () => _printBill(detail),
        ),
      IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: _order.refresh),
    ];

    // Đơn đã đóng: chỉ xem lại món + thanh toán.
    if (!showMenu) {
      return Scaffold(
        appBar: AppBar(title: appBarTitle, actions: actions, bottom: progress),
        body: orderPanel,
        bottomNavigationBar: summary,
      );
    }

    if (wide) {
      return Scaffold(
        appBar: AppBar(title: appBarTitle, actions: actions, bottom: progress),
        body: Row(
          children: [
            Expanded(child: menu),
            const VerticalDivider(width: 1),
            SizedBox(
              width: layout.orderPanelWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Text('Món đã gọi', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        if (detail.pendingCount > 0) PendingBadge(count: detail.pendingCount),
                      ],
                    ),
                  ),
                  Expanded(child: orderPanel),
                  summary,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: appBarTitle,
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Column(
              children: [
                TabBar(tabs: [
                  const Tab(height: 46, text: 'Thực đơn'),
                  Tab(height: 46, text: 'Món đã gọi (${detail.activeItemCount})'),
                ]),
                progress,
              ],
            ),
          ),
        ),
        body: TabBarView(children: [menu, orderPanel]),
        bottomNavigationBar: summary,
      ),
    );
  }
}
