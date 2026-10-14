import '../core/api_client.dart';
import '../models/models.dart';

/// Các lệnh POS trên /api/v1 (xem application/controllers/Api_pos.php phía máy chủ).
class PosRepository {
  PosRepository(this.api);

  final ApiClient api;

  List<PosTable> _tables(Map<String, dynamic> res) => (res['tables'] as List)
      .map((t) => PosTable.fromJson(t as Map<String, dynamic>))
      .toList(growable: false);

  Future<List<PosTable>> tables() async => _tables(await api.get('tables'));

  Future<OrderDetail> openTable(int tableId) async =>
      OrderDetail.fromJson(await api.post('tables/$tableId/open'));

  Future<List<PosTable>> transferTable(int tableId, int targetTableId) async =>
      _tables(await api.post('tables/$tableId/transfer', {'target_table_id': targetTableId}));

  Future<OrderDetail> mergeTable(int tableId, int targetTableId) async =>
      OrderDetail.fromJson(await api.post('tables/$tableId/merge', {'target_table_id': targetTableId}));

  Future<List<MenuCategory>> menu() async {
    final res = await api.get('menu');
    return (res['categories'] as List)
        .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<OrderSummary>> activeOrders() async {
    final res = await api.get('orders/active');
    return (res['orders'] as List)
        .map((o) => OrderSummary.fromJson(o as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Đơn do người đang đăng nhập tạo trong ngày (mặc định hôm nay).
  Future<OrderHistory> orderHistory({String? date}) async =>
      OrderHistory.fromJson(await api.get(date == null ? 'orders/history' : 'orders/history?date=$date'));

  Future<OrderDetail> order(int orderId) async => OrderDetail.fromJson(await api.get('orders/$orderId'));

  Future<OrderDetail> setOrderNote(int orderId, String? note) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'note': note}));

  /// Bảng giá có hiệu lực hôm nay (đang bật, trong khoảng ngày, đúng thứ) kèm giá từng món.
  Future<List<PriceBook>> priceBooks() async {
    final res = await api.get('price-books');
    return (res['price_books'] as List)
        .map((b) => PriceBook.fromJson(b as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Bảng giá + khuyến mãi đang chọn ở Sơ đồ bàn (dùng chung mọi máy) và các lựa chọn có hiệu lực hôm nay.
  Future<ShopOffers> offers() async => ShopOffers.fromJson(await api.get('offers'));

  /// Chọn ở Sơ đồ bàn (null = bỏ): máy chủ áp ngay cho mọi đơn đang mở và bàn mở sau.
  Future<ShopOffers> setOffers({int? priceBookId, int? discountId}) async =>
      ShopOffers.fromJson(await api.post('offers', {'price_book_id': priceBookId, 'discount_id': discountId}));

  /// Bỏ bảng giá cho riêng đơn này — mọi món về giá gốc (chọn bảng giá làm ở Sơ đồ bàn).
  Future<OrderDetail> removePriceBook(int orderId) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'price_book_id': null}));

  /// Bỏ khuyến mãi cho riêng đơn này.
  Future<OrderDetail> removeDiscount(int orderId) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'discount_id': null}));

  /// Áp lại bảng giá / khuyến mãi đang chọn ở Sơ đồ bàn cho đơn đã bỏ ([id] phải đúng lựa chọn ở Sơ đồ bàn).
  Future<OrderDetail> reapplyPriceBook(int orderId, int priceBookId) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'price_book_id': priceBookId}));

  Future<OrderDetail> reapplyDiscount(int orderId, int discountId) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'discount_id': discountId}));

  /// Sổ quỹ: loại thu, gợi ý người nộp, phiếu thu người này đã lập hôm nay.
  Future<CashReceiptsData> cashReceipts() async => CashReceiptsData.fromJson(await api.get('cashbook/receipts'));

  /// Lập phiếu thu ngay bây giờ (nhân viên thu = người đang đăng nhập).
  Future<CashReceipt> createCashReceipt({
    required int categoryId,
    required PaymentMethod method,
    required double amount,
    String? counterparty,
    String? note,
  }) async {
    final res = await api.post('cashbook/receipts', {
      'category_id': categoryId,
      'payment_method': method.code,
      'amount': amount,
      'counterparty': counterparty,
      'note': note,
    });
    return CashReceipt.fromJson(res['receipt'] as Map<String, dynamic>);
  }

  /// Báo cáo cuối ngày của người đang đăng nhập: từ 00:00 hôm nay tới bây giờ.
  Future<ShiftReport> shiftReport() async {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final from = '${now.year}-${two(now.month)}-${two(now.day)} 00:00';
    return ShiftReport.fromJson(await api.get('reports/shift?from=${Uri.encodeQueryComponent(from)}'));
  }

  /// Đổi mật khẩu — các thiết bị khác phải đăng nhập lại, máy này vẫn giữ phiên.
  Future<String> changePassword(String current, String next) async {
    final res = await api.post('auth/password', {'current_password': current, 'new_password': next});
    return (res['message'] as String?) ?? 'Đã đổi mật khẩu.';
  }

  Future<OrderDetail> addItem(int orderId, int productId, {int qty = 1, String? note}) async =>
      OrderDetail.fromJson(await api.post('orders/$orderId/items', {
        'items': [
          {'product_id': productId, 'qty': qty, if (note != null && note.isNotEmpty) 'note': note},
        ],
      }));

  Future<OrderDetail> setItemQty(int orderId, int itemId, int qty) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId/items/$itemId', {'qty': qty}));

  Future<OrderDetail> setItemNote(int orderId, int itemId, String? note) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId/items/$itemId', {'note': note}));

  Future<OrderDetail> removeItem(int orderId, int itemId) async =>
      OrderDetail.fromJson(await api.delete('orders/$orderId/items/$itemId'));

  /// Ảnh trình chiếu + tuỳ chọn màn hình khách (Quản trị → Màn hình khách trên web).
  Future<Map<String, dynamic>> displayConfig() => api.get('display/config');

  /// Các lần báo bếp của đơn (cả từ web), mới nhất trước.
  Future<List<KitchenSlip>> kitchenHistory(int orderId) async {
    final res = await api.get('orders/$orderId/kitchen-history');
    return (res['history'] as List)
        .map((h) => KitchenSlip.fromJson(h as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<OrderDetail> notifyKitchen(int orderId) async =>
      OrderDetail.fromJson(await api.post('orders/$orderId/notify'));

  Future<OrderDetail> pay(int orderId, PaymentMethod method, {double receivedAmount = 0}) async =>
      OrderDetail.fromJson(await api.post('orders/$orderId/pay', {
        'payment_method': method.code,
        'received_amount': receivedAmount,
      }));
}
