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

  Future<OrderDetail> order(int orderId) async => OrderDetail.fromJson(await api.get('orders/$orderId'));

  Future<OrderDetail> setOrderNote(int orderId, String? note) async =>
      OrderDetail.fromJson(await api.patch('orders/$orderId', {'note': note}));

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
