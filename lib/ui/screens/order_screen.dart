import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../customer_display/customer_display_controller.dart';
import '../../models/models.dart';
import '../../state/auth.dart';
import '../../state/pos.dart';
import '../../state/printing.dart';
import '../layout.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dialogs.dart';
import '../widgets/menu_panel.dart';
import '../widgets/offers.dart';
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

  // Ô tìm món luôn hiện trên thanh tiêu đề, cùng hàng với tên bàn (khi đơn đang mở).
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // Màn hình khách: lấy sẵn để còn dùng được trong dispose().
  late final CustomerDisplayController _display = ref.read(customerDisplayProvider.notifier);

  // Rời màn hình đơn (về sơ đồ bàn hoặc chuyển sang bàn khác) -> làm mới tiền trên sơ đồ bàn ngay.
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    // Đơn mở / thay đổi (thêm, bớt món, máy khác sửa) -> cập nhật màn hình khách.
    ref.listenManual(orderProvider(widget.orderId), (_, next) {
      final detail = next.valueOrNull;
      if (detail != null) Future.microtask(() => _display.showOrder(detail));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _display.leaveOrder(widget.orderId);
    if (_container.exists(tablesProvider)) _container.read(tablesProvider.notifier).refreshSilently();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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
    // Đơn đang dùng bảng giá -> hiện giá mới (máy chủ cũng tính theo bảng giá khi thêm món).
    final bookId = ref.read(orderProvider(widget.orderId)).valueOrNull?.order.priceBookId;
    final book = bookId == null
        ? null
        : ref.read(priceBooksProvider).valueOrNull?.where((b) => b.id == bookId).firstOrNull;
    final result = await showAddProductDialog(context, p, price: book?.priceOf(p));
    if (result == null) return;
    await _act(() => _order.addProduct(p, qty: result.qty, note: result.note));
  }

  /// Chuyển sang đơn của bàn khác (thay màn hình này, Quay lại vẫn về sơ đồ bàn).
  void _switchTo(OrderSummary other) {
    if (other.id == widget.orderId) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => OrderScreen(orderId: other.id),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ---- Chuyển bàn / gộp bàn ngay trên màn hình đơn (giống nhấn giữ bàn ở sơ đồ bàn) ----

  Future<List<PosTable>?> _loadTables() async {
    try {
      return await ref.read(posRepositoryProvider).tables();
    } catch (e) {
      if (mounted) showError(context, e);
      return null;
    }
  }

  /// Chuyển khách của bàn này sang một bàn trống — đơn giữ nguyên, chỉ đổi bàn.
  Future<void> _transferTable(Order order) async {
    final tableId = order.tableId;
    if (tableId == null) return;
    final tables = await _loadTables();
    if (tables == null || !mounted) return;
    final target = await showPickerDialog<PosTable>(
      context,
      title: 'Chuyển ${order.tableName} sang…',
      options: tables.where((t) => t.isAvailable && !t.isTakeaway && t.id != tableId).toList(),
      label: (t) => t.name,
      subtitle: (t) => '${t.capacity} chỗ',
      emptyText: 'Không còn bàn trống.',
    );
    if (target == null || !mounted) return;
    final ok = await _act(() async {
      await ref.read(posRepositoryProvider).transferTable(tableId, target.id);
      await _order.refresh(); // tên bàn mới
      return true;
    });
    if (ok != null && mounted) showMessage(context, 'Đã chuyển ${order.tableName} sang ${target.name}.');
  }

  /// Gộp đơn của bàn này vào bàn khác đang phục vụ, rồi mở đơn của bàn đó.
  Future<void> _mergeTable(Order order) async {
    final tableId = order.tableId;
    if (tableId == null) return;
    final tables = await _loadTables();
    if (tables == null || !mounted) return;
    final target = await showPickerDialog<PosTable>(
      context,
      title: 'Gộp ${order.tableName} vào…',
      options: tables.where((t) => !t.isAvailable && t.order != null && !t.isTakeaway && t.id != tableId).toList(),
      label: (t) => t.name,
      subtitle: (t) => formatMoney(t.order!.totalAmount),
      emptyText: 'Không có bàn nào khác đang phục vụ.',
    );
    if (target == null || !mounted) return;
    if (!await confirmDialog(context,
        title: 'Gộp ${order.tableName} vào ${target.name}?',
        message: 'Toàn bộ món của ${order.tableName} sẽ chuyển sang đơn của ${target.name}, ${order.tableName} trở về Trống.',
        confirmLabel: 'Gộp bàn')) {
      return;
    }
    final merged = await _act(() => ref.read(posRepositoryProvider).mergeTable(tableId, target.id));
    if (merged == null || !mounted) return;
    showMessage(context, 'Đã gộp ${order.tableName} vào ${target.name}.');
    _switchTo(OrderSummary(
      id: merged.order.id,
      orderNo: merged.order.orderNo,
      status: merged.order.status,
      totalAmount: merged.order.totalAmount,
    ));
  }

  void _setQty(OrderItem item, int qty) => _act(() => _order.setQty(item, qty));

  /// Bỏ bảng giá / khuyến mãi cho riêng đơn này (chọn làm ở Sơ đồ bàn, áp cho mọi đơn đang mở).
  void _removePriceBook() => _act(() => _order.removePriceBook());

  void _removeDiscount() => _act(() => _order.removeDiscount());

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

    // Màn hình khách: bảng thanh toán mở với Tiền mặt; chọn Chuyển khoản thì hiện mã VietQR cho khách.
    _display.startPaying(latest, PaymentMethod.cash);
    final input = await showPaymentSheet(
      context,
      total: latest.order.totalAmount,
      title: latest.order.tableName,
      bankQr: ref.read(shopSettingsProvider)?.bankQr,
      onMethodChanged: (m) => _display.startPaying(latest, m),
    );
    if (input == null || !mounted) {
      _display.cancelPaying(latest.order.id);
      return;
    }

    final paid = await _act(() => _order.pay(input.method, receivedAmount: input.received));
    if (paid == null || !mounted) {
      _display.cancelPaying(latest.order.id);
      return;
    }
    _display.showThanks(paid);

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

    // "Món đã gọi": thẻ bảng giá / khuyến mãi của đơn ở trên (giống web), danh sách món bên dưới.
    final orderPanel = Column(
      children: [
        OrderOfferChips(
          order: order,
          active: detail.isActive,
          editable: detail.isActive && _busy == 0,
          onRemovePriceBook: _removePriceBook,
          onRemoveDiscount: _removeDiscount,
          onReapplyPriceBook: (id) => _act(() => _order.reapplyPriceBook(id)),
          onReapplyDiscount: (id) => _act(() => _order.reapplyDiscount(id)),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _order.refresh,
            child: OrderPanel(
              detail: detail,
              showPendingBadge: !wide,
              onQty: _setQty,
              onNote: _editItemNote,
              onRemove: _removeItem,
            ),
          ),
        ),
      ],
    );
    final summary = OrderSummaryBar(
      detail: detail,
      onNotify: _busy > 0 ? null : _notifyKitchen,
      onPrintBill: _busy > 0 ? null : () => _printBill(detail),
      onPay: _busy > 0 ? null : () => _pay(detail),
    );
    final menu = MenuPanel(detail: detail, onAdd: _add, onAddWithOptions: _addWithOptions, query: _query);
    final searching = showMenu;

    // Tên bàn + mũi tên: bấm để chuyển sang bàn đang phục vụ khác mà không phải về sơ đồ bàn.
    final nameColumn = _TableSwitcher(
      current: order,
      onSwitch: _switchTo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(order.tableName, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          Text('${order.orderNo} · ${Status.orderLabel(order.status)}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    // Chuyển / gộp bàn: đơn đang mở của bàn thường, người có quyền sơ đồ bàn.
    final canMoveTable =
        detail.isActive && order.tableId != null && (ref.watch(authProvider).valueOrNull?.user.canTables ?? false);
    // Điện thoại: ô tìm món rộng hết màn hình ở đầu tab Thực đơn (thanh tiêu đề chỉ còn tên bàn).
    final phoneSearch = Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: _SearchField(
          hint: 'Tìm món (vd: ca phe sua)',
          controller: _searchCtrl,
          focusNode: _searchFocus,
          large: true,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
    );
    final appBarTitle = !searching || !wide
        ? nameColumn
        : Row(
            children: [
              Flexible(child: nameColumn),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                // Builder: lấy được TabController để nhảy về tab Thực đơn khi gõ (điện thoại).
                child: Builder(
                  builder: (context) => _SearchField(
                    hint: wide ? 'Tìm món (vd: ca phe sua)' : 'Tìm món',
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) {
                      setState(() => _query = v);
                      DefaultTabController.maybeOf(context)?.animateTo(0);
                    },
                  ),
                ),
              ),
            ],
          );
    // Điện thoại: gom các nút ít dùng vào menu ⋮ để ô tìm món đủ rộng.
    final actions = !wide && searching
        ? <Widget>[
            PopupMenuButton<VoidCallback>(
              tooltip: 'Thêm',
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => _editOrderNote(order),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon((order.note ?? '').isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2),
                    title: const Text('Ghi chú đơn'),
                  ),
                ),
                PopupMenuItem(
                  value: () => showKitchenHistory(context, order),
                  child: const ListTile(
                      contentPadding: EdgeInsets.zero, leading: Icon(Icons.history), title: Text('Lịch sử báo bếp')),
                ),
                if (canMoveTable) ...[
                  PopupMenuItem(
                    value: () => _transferTable(order),
                    child: const ListTile(
                        contentPadding: EdgeInsets.zero, leading: Icon(Icons.swap_horiz), title: Text('Chuyển bàn')),
                  ),
                  PopupMenuItem(
                    value: () => _mergeTable(order),
                    child: const ListTile(
                        contentPadding: EdgeInsets.zero, leading: Icon(Icons.merge_type), title: Text('Gộp bàn')),
                  ),
                ],
                PopupMenuItem(
                  value: _order.refresh,
                  child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.refresh), title: Text('Tải lại')),
                ),
              ],
            ),
            const AppMenuButton(),
          ]
        : <Widget>[
      if (canMoveTable)
        PopupMenuButton<VoidCallback>(
          tooltip: 'Chuyển / gộp bàn',
          icon: const Icon(Icons.swap_horiz),
          enabled: _busy == 0,
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: () => _transferTable(order),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.swap_horiz),
                title: Text('Chuyển bàn'),
                subtitle: Text('Chuyển khách sang một bàn trống'),
              ),
            ),
            PopupMenuItem(
              value: () => _mergeTable(order),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.merge_type),
                title: Text('Gộp bàn'),
                subtitle: Text('Gộp đơn này vào bàn khác đang phục vụ'),
              ),
            ),
          ],
        ),
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
      const AppMenuButton(),
    ];

    // Đơn đã đóng: chỉ xem lại món + thanh toán.
    if (!showMenu) {
      return Scaffold(
        endDrawer: const AppDrawer(current: AppPage.order),
        appBar: AppBar(title: appBarTitle, actions: actions, bottom: progress),
        body: orderPanel,
        bottomNavigationBar: summary,
      );
    }

    if (wide) {
      return Scaffold(
        endDrawer: const AppDrawer(current: AppPage.order),
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
        endDrawer: const AppDrawer(current: AppPage.order),
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
        body: TabBarView(children: [
          // Ô tìm món rộng hết màn hình ngay trên thực đơn.
          Column(children: [phoneSearch, Expanded(child: menu)]),
          orderPanel,
        ]),
        bottomNavigationBar: summary,
      ),
    );
  }
}

/// Ô tìm món trên thanh tiêu đề (không cần gõ dấu: "ca phe sua" ra "Cà phê sữa").
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hint,
    this.large = false,
  });

  final String hint;

  /// Ô to (điện thoại, rộng hết màn hình): cao hơn, chữ và biểu tượng to hơn cho dễ bấm.
  final bool large;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: large ? 52 : 44,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          style: large ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            contentPadding: EdgeInsets.symmetric(vertical: large ? 14 : 10),
            prefixIcon: Icon(Icons.search, size: large ? 24 : 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(large ? 26 : 22), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
}


/// Tên bàn trên thanh tiêu đề màn hình đơn: bấm mở danh sách bàn đang phục vụ để chuyển sang đơn khác ngay
/// (không phải về sơ đồ bàn). Mở bàn mới vẫn làm ở sơ đồ bàn — mục cuối danh sách đưa về đó.
class _TableSwitcher extends ConsumerStatefulWidget {
  const _TableSwitcher({required this.current, required this.onSwitch, required this.child});

  final Order current;
  final ValueChanged<OrderSummary> onSwitch;
  final Widget child;

  @override
  ConsumerState<_TableSwitcher> createState() => _TableSwitcherState();
}

class _TableSwitcherState extends ConsumerState<_TableSwitcher> {
  bool _loading = false;

  /// "Mang đi" trước, rồi theo số bàn (Bàn 2 trước Bàn 10).
  static int _compare(OrderSummary a, OrderSummary b) {
    if ((a.tableId == null) != (b.tableId == null)) return a.tableId == null ? -1 : 1;
    int? num(String? s) => int.tryParse(RegExp(r'\d+').firstMatch(s ?? '')?.group(0) ?? '');
    final na = num(a.tableName), nb = num(b.tableName);
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    return (a.tableName ?? '').compareTo(b.tableName ?? '');
  }

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final canTables = ref.read(authProvider).valueOrNull?.user.canTables ?? true;
    List<OrderSummary> orders;
    try {
      // Luôn lấy mới: máy khác / web có thể vừa mở hoặc đóng bàn. Có quyền sơ đồ bàn: đúng các bàn đang có khách
      // trên sơ đồ (không lẫn đơn cũ còn mở mà bàn đã trống); không thì danh sách đơn đang phục vụ.
      if (canTables) {
        final tables = await ref.read(posRepositoryProvider).tables();
        orders = [
          for (final t in tables)
            if (!t.isAvailable && t.order != null)
              OrderSummary(
                id: t.order!.id,
                orderNo: t.order!.orderNo,
                status: t.order!.status,
                totalAmount: t.order!.totalAmount,
                tableId: t.isTakeaway ? null : t.id,
                tableName: t.name,
              ),
        ];
        if (ref.exists(tablesProvider)) ref.read(tablesProvider.notifier).refreshSilently();
      } else {
        orders = [...await ref.refresh(activeOrdersProvider.future)];
      }
      orders.sort(_compare);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
    final others = orders.where((o) => o.id != widget.current.id).length;

    // -1 = về sơ đồ bàn để mở bàn mới.
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(topLeft.dx, topLeft.dy, overlay.size.width - topLeft.dx, 0),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          height: 32,
          child: Text('BÀN ĐANG PHỤC VỤ',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.outline, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        for (final o in orders)
          PopupMenuItem<int>(
            value: o.id,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: o.id == widget.current.id ? Icon(Icons.check, size: 20, color: scheme.primary) : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        o.tableName ?? 'Mang đi',
                        style: TextStyle(
                          fontWeight: o.id == widget.current.id ? FontWeight.w700 : FontWeight.w500,
                          color: o.id == widget.current.id ? scheme.primary : null,
                        ),
                      ),
                      if (o.status != Status.open)
                        Text(Status.orderLabel(o.status),
                            style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange.shade800)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatMoney(o.totalAmount), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        if (others == 0)
          const PopupMenuItem<int>(enabled: false, child: Text('Không có bàn nào khác đang phục vụ.')),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              SizedBox(width: 28, child: Icon(canTables ? Icons.add : Icons.list_alt, size: 20, color: scheme.primary)),
              Expanded(
                child: Text(canTables ? 'Mở bàn mới — về sơ đồ bàn' : 'Về danh sách đơn',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
    if (!mounted || picked == null) return;
    if (picked == -1) {
      Navigator.of(context).pop();
      return;
    }
    final target = orders.where((o) => o.id == picked).firstOrNull;
    if (target != null) widget.onSwitch(target);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: widget.child),
            if (_loading) ...[
              const SizedBox(width: 6),
              const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}
