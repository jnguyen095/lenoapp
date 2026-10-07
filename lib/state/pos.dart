import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pos_repository.dart';
import '../models/models.dart';
import 'auth.dart';

/// Sơ đồ bàn, tự làm mới mỗi 15 giây khi đang mở (máy khác/web có thể vừa mở bàn).
final tablesProvider = AsyncNotifierProvider.autoDispose<TablesController, List<PosTable>>(TablesController.new);

class TablesController extends AutoDisposeAsyncNotifier<List<PosTable>> {
  static const refreshInterval = Duration(seconds: 15);

  bool _disposed = false;

  PosRepository get _repo => ref.read(posRepositoryProvider);

  @override
  Future<List<PosTable>> build() async {
    _disposed = false;
    final timer = Timer.periodic(refreshInterval, (_) => refreshSilently());
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });
    return ref.watch(posRepositoryProvider).tables();
  }

  /// Làm mới nền: lỗi mạng tạm thời thì giữ nguyên sơ đồ đang hiện.
  Future<void> refreshSilently() async {
    try {
      final tables = await _repo.tables();
      if (!_disposed) state = AsyncData(tables);
    } catch (_) {}
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(_repo.tables);
    if (!_disposed) state = result;
  }

  Future<OrderDetail> openTable(PosTable table) => _repo.openTable(table.id);

  Future<void> transfer(PosTable from, PosTable to) async {
    final tables = await _repo.transferTable(from.id, to.id);
    if (!_disposed) state = AsyncData(tables);
  }

  Future<OrderDetail> merge(PosTable from, PosTable into) async {
    final detail = await _repo.mergeTable(from.id, into.id);
    unawaited(refreshSilently());
    return detail;
  }
}

/// Đơn đang phục vụ — cho tài khoản chỉ có quyền Đơn hàng (không có Sơ đồ bàn).
final activeOrdersProvider = FutureProvider.autoDispose<List<OrderSummary>>(
  (ref) => ref.watch(posRepositoryProvider).activeOrders(),
);

/// Thực đơn: giữ trong suốt phiên đăng nhập, kéo xuống để tải lại.
final menuProvider = FutureProvider<List<MenuCategory>>((ref) => ref.watch(posRepositoryProvider).menu());

/// Một đơn đang mở. Mọi thao tác chạy tuần tự (bấm nhanh nhiều món không bị đè kết quả)
/// và thay state bằng đơn mới nhất máy chủ trả về. Lỗi ném ra cho màn hình hiện thông báo.
final orderProvider =
    AsyncNotifierProvider.autoDispose.family<OrderController, OrderDetail, int>(OrderController.new);

class OrderController extends AutoDisposeFamilyAsyncNotifier<OrderDetail, int> {
  Future<void> _queue = Future.value();
  bool _disposed = false;

  PosRepository get _repo => ref.read(posRepositoryProvider);

  @override
  Future<OrderDetail> build(int arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return ref.watch(posRepositoryProvider).order(arg);
  }

  Future<OrderDetail> _run(Future<OrderDetail> Function() action) {
    final next = _queue.then((_) => action()).then((detail) {
      if (!_disposed) state = AsyncData(detail);
      return detail;
    });
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(() => _repo.order(arg));
    // Giữ đơn đang hiện nếu chỉ là lỗi mạng tạm thời.
    if (!_disposed && (result.hasValue || !state.hasValue)) state = result;
  }

  Future<OrderDetail> addProduct(Product p, {int qty = 1, String? note}) =>
      _run(() => _repo.addItem(arg, p.id, qty: qty, note: note));

  Future<OrderDetail> setQty(OrderItem item, int qty) => _run(() => _repo.setItemQty(arg, item.id, qty));

  Future<OrderDetail> setItemNote(OrderItem item, String? note) =>
      _run(() => _repo.setItemNote(arg, item.id, note));

  Future<OrderDetail> removeItem(OrderItem item) => _run(() => _repo.removeItem(arg, item.id));

  Future<OrderDetail> setNote(String? note) => _run(() => _repo.setOrderNote(arg, note));

  Future<OrderDetail> notifyKitchen() => _run(() => _repo.notifyKitchen(arg));

  Future<OrderDetail> pay(PaymentMethod method, {double receivedAmount = 0}) =>
      _run(() => _repo.pay(arg, method, receivedAmount: receivedAmount));
}

/// Lịch sử báo bếp của một đơn (từ nhật ký máy chủ, gồm cả các lần báo trên web).
final kitchenHistoryProvider = FutureProvider.autoDispose.family<List<KitchenSlip>, int>(
  (ref, orderId) => ref.watch(posRepositoryProvider).kitchenHistory(orderId),
);
