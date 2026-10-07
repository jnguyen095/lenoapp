// Mô hình dữ liệu khớp JSON của /api/v1 (xem application/helpers/api_helper.php phía máy chủ).

int _int(dynamic v) => (v as num).toInt();
int? _intOrNull(dynamic v) => v == null ? null : (v as num).toInt();
double _money(dynamic v) => v == null ? 0 : (v as num).toDouble();
String? _str(dynamic v) => v as String?;

class User {
  const User({
    required this.id,
    required this.username,
    required this.fullname,
    required this.role,
    required this.roleLabel,
    required this.canTables,
    required this.canOrders,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    final perms = (j['permissions'] as Map?) ?? const {};
    return User(
      id: _int(j['id']),
      username: j['username'] as String,
      fullname: j['fullname'] as String,
      role: j['role'] as String,
      roleLabel: j['role_label'] as String,
      canTables: perms['tables'] == true,
      canOrders: perms['orders'] == true,
    );
  }

  final int id;
  final String username;
  final String fullname;
  final String role;
  final String roleLabel;

  /// Được dùng Sơ đồ bàn (mở bàn, chuyển/gộp bàn).
  final bool canTables;

  /// Được gọi món, báo bếp, thanh toán.
  final bool canOrders;
}

class ShopSettings {
  const ShopSettings({required this.siteName, required this.vatPercent, required this.takeawayEnabled});

  factory ShopSettings.fromJson(Map<String, dynamic> j) => ShopSettings(
        siteName: (j['site_name'] as String?) ?? 'Leno',
        vatPercent: _money(j['vat_percent']),
        takeawayEnabled: j['takeaway_enabled'] == true,
      );

  final String siteName;
  final double vatPercent;
  final bool takeawayEnabled;
}

/// Trạng thái bàn/đơn giống web.
class Status {
  static const available = 'AVAILABLE';
  static const open = 'OPEN';
  static const waitPayment = 'WAIT_PAYMENT';
  static const paid = 'PAID';
  static const cancelled = 'CANCELLED';

  static String tableLabel(String s) => switch (s) {
        available => 'Trống',
        open => 'Đang phục vụ',
        waitPayment => 'Chờ thanh toán',
        paid => 'Đã thanh toán',
        _ => s,
      };

  static String orderLabel(String s) => switch (s) {
        open => 'Đang mở',
        waitPayment => 'Chờ thanh toán',
        paid => 'Đã thanh toán',
        cancelled => 'Đã hủy',
        _ => s,
      };
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.totalAmount,
    this.createdAt,
    this.tableId,
    this.tableName,
    this.itemCount,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        id: _int(j['id']),
        orderNo: j['order_no'] as String,
        status: j['status'] as String,
        totalAmount: _money(j['total_amount']),
        createdAt: _str(j['created_at']),
        tableId: _intOrNull(j['table_id']),
        tableName: _str(j['table_name']),
        itemCount: _intOrNull(j['item_count']),
      );

  final int id;
  final String orderNo;
  final String status;
  final double totalAmount;
  final String? createdAt;
  final int? tableId;
  final String? tableName;
  final int? itemCount;
}

class PosTable {
  const PosTable({
    required this.id,
    required this.code,
    required this.name,
    required this.note,
    required this.capacity,
    required this.isTakeaway,
    required this.status,
    required this.order,
  });

  factory PosTable.fromJson(Map<String, dynamic> j) => PosTable(
        id: _int(j['id']),
        code: j['code'] as String,
        name: j['name'] as String,
        note: _str(j['note']),
        capacity: _int(j['capacity']),
        isTakeaway: j['is_takeaway'] == true,
        status: j['status'] as String,
        order: j['order'] == null ? null : OrderSummary.fromJson(j['order'] as Map<String, dynamic>),
      );

  final int id;
  final String code;
  final String name;
  final String? note;
  final int capacity;
  final bool isTakeaway;
  final String status;
  final OrderSummary? order;

  bool get isAvailable => status == Status.available;
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.sku,
    required this.name,
    required this.price,
    this.image,
    this.description,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _int(j['id']),
        categoryId: _int(j['category_id']),
        sku: j['sku'] as String,
        name: j['name'] as String,
        price: _money(j['price']),
        image: _str(j['image']),
        description: _str(j['description']),
      );

  final int id;
  final int categoryId;
  final String sku;
  final String name;
  final double price;
  final String? image;
  final String? description;
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.products});

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: _int(j['id']),
        name: j['name'] as String,
        products: (j['products'] as List)
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
      );

  final int id;
  final String name;
  final List<Product> products;
}

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.orderType,
    required this.status,
    required this.note,
    required this.tableId,
    required this.tableName,
    required this.tableNote,
    required this.createdByName,
    required this.subtotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.paidAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _int(j['id']),
        orderNo: j['order_no'] as String,
        orderType: j['order_type'] as String,
        status: j['status'] as String,
        note: _str(j['note']),
        tableId: _intOrNull(j['table_id']),
        tableName: (j['table_name'] as String?) ?? 'Mang đi',
        tableNote: _str(j['table_note']),
        createdByName: _str(j['created_by_name']),
        subtotal: _money(j['subtotal']),
        discountAmount: _money(j['discount_amount']),
        vatAmount: _money(j['vat_amount']),
        totalAmount: _money(j['total_amount']),
        createdAt: _str(j['created_at']),
        paidAt: _str(j['paid_at']),
      );

  final int id;
  final String orderNo;
  final String orderType;
  final String status;
  final String? note;
  final int? tableId;
  final String tableName;
  final String? tableNote;
  final String? createdByName;
  final double subtotal;
  final double discountAmount;
  final double vatAmount;
  final double totalAmount;
  final String? createdAt;
  final String? paidAt;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.image,
    required this.qty,
    required this.notifiedQty,
    required this.price,
    required this.amount,
    required this.note,
    required this.notifiedNote,
    required this.status,
    required this.pending,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: _int(j['id']),
        productId: _int(j['product_id']),
        productName: j['product_name'] as String,
        image: _str(j['image']),
        qty: _int(j['qty']),
        notifiedQty: _int(j['notified_qty']),
        price: _money(j['price']),
        amount: _money(j['amount']),
        note: _str(j['note']),
        notifiedNote: _str(j['notified_note']),
        status: j['status'] as String,
        pending: j['pending'] == true,
      );

  final int id;
  final int productId;
  final String productName;
  final String? image;
  final int qty;
  final int notifiedQty;
  final double price;
  final double amount;
  final String? note;
  final String? notifiedNote;
  final String status;

  /// Còn phần chưa báo bếp (món mới, đổi số lượng, đổi ghi chú).
  final bool pending;

  bool get isCancelled => status == Status.cancelled;
}

class Payment {
  const Payment({
    required this.id,
    required this.method,
    required this.methodLabel,
    required this.amount,
    required this.receivedAmount,
    required this.changeAmount,
    required this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: _int(j['id']),
        method: j['payment_method'] as String,
        methodLabel: j['method_label'] as String,
        amount: _money(j['amount']),
        receivedAmount: _money(j['received_amount']),
        changeAmount: _money(j['change_amount']),
        paidAt: _str(j['paid_at']),
      );

  final int id;
  final String method;
  final String methodLabel;
  final double amount;
  final double receivedAmount;
  final double changeAmount;
  final String? paidAt;
}

class SlipLine {
  const SlipLine({required this.productId, required this.productName, required this.qty, this.note, this.oldNote});

  factory SlipLine.fromJson(Map<String, dynamic> j) => SlipLine(
        productId: _int(j['product_id']),
        productName: j['product_name'] as String,
        qty: _int(j['qty']),
        note: _str(j['note']),
        oldNote: _str(j['old_note']),
      );

  final int productId;
  final String productName;
  final int qty;
  final String? note;
  final String? oldNote;
}

/// Phần vừa báo bếp ("Thông báo"): món mới, món hủy, món đổi ghi chú.
class KitchenSlip {
  const KitchenSlip({
    required this.send,
    required this.cancel,
    required this.changed,
    required this.orderNote,
    required this.createdAt,
    required this.staff,
  });

  bool get isEmpty => send.isEmpty && cancel.isEmpty && changed.isEmpty;

  /// Bản chỉ gồm các dòng thỏa [keep] (tách phiếu theo máy in).
  KitchenSlip where(bool Function(SlipLine line) keep) => KitchenSlip(
        send: send.where(keep).toList(growable: false),
        cancel: cancel.where(keep).toList(growable: false),
        changed: changed.where(keep).toList(growable: false),
        orderNote: orderNote,
        createdAt: createdAt,
        staff: staff,
      );

  factory KitchenSlip.fromJson(Map<String, dynamic> j) {
    List<SlipLine> lines(String key) => ((j[key] as List?) ?? const [])
        .map((l) => SlipLine.fromJson(l as Map<String, dynamic>))
        .toList(growable: false);
    return KitchenSlip(
      send: lines('send'),
      cancel: lines('cancel'),
      changed: lines('changed'),
      orderNote: _str(j['order_note']),
      createdAt: _str(j['created_at']),
      staff: _str(j['staff']),
    );
  }

  final List<SlipLine> send;
  final List<SlipLine> cancel;
  final List<SlipLine> changed;
  final String? orderNote;
  final String? createdAt;
  final String? staff;
}

/// Phản hồi đầy đủ của mọi API thao tác trên đơn.
class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.isActive,
    required this.items,
    required this.pendingCount,
    this.payment,
    this.kitchenSlip,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
        order: Order.fromJson(j['order'] as Map<String, dynamic>),
        isActive: j['is_active'] == true,
        items: (j['items'] as List)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(growable: false),
        pendingCount: _int(j['pending_count']),
        payment: j['payment'] == null ? null : Payment.fromJson(j['payment'] as Map<String, dynamic>),
        kitchenSlip:
            j['kitchen_slip'] == null ? null : KitchenSlip.fromJson(j['kitchen_slip'] as Map<String, dynamic>),
      );

  final Order order;
  final bool isActive;
  final List<OrderItem> items;
  final int pendingCount;
  final Payment? payment;
  final KitchenSlip? kitchenSlip;

  /// Tổng số lượng đang gọi của một món (để hiện huy hiệu trên thực đơn).
  int qtyOfProduct(int productId) =>
      items.where((i) => i.productId == productId && !i.isCancelled).fold(0, (sum, i) => sum + i.qty);

  int get activeItemCount => items.where((i) => !i.isCancelled).fold(0, (sum, i) => sum + i.qty);
}

/// Phương thức thanh toán (khớp Pos_service::PAYMENT_METHODS).
enum PaymentMethod {
  cash('CASH', 'Tiền mặt'),
  transfer('TRANSFER', 'Chuyển khoản'),
  card('CARD', 'Thẻ'),
  qr('QR', 'QR Pay');

  const PaymentMethod(this.code, this.label);

  final String code;
  final String label;
}

/// Một đơn trong "Lịch sử đơn hàng" của nhân viên.
class HistoryOrder {
  const HistoryOrder({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.tableName,
    required this.totalAmount,
    required this.itemCount,
    this.tableId,
    this.note,
    this.methodLabel,
    this.createdAt,
    this.paidAt,
  });

  factory HistoryOrder.fromJson(Map<String, dynamic> j) => HistoryOrder(
        id: _int(j['id']),
        orderNo: j['order_no'] as String,
        status: j['status'] as String,
        tableId: _intOrNull(j['table_id']),
        tableName: (j['table_name'] as String?) ?? 'Mang đi',
        totalAmount: _money(j['total_amount']),
        itemCount: _int(j['item_count']),
        note: _str(j['note']),
        methodLabel: _str(j['method_label']),
        createdAt: _str(j['created_at']),
        paidAt: _str(j['paid_at']),
      );

  final int id;
  final String orderNo;
  final String status;
  final int? tableId;
  final String tableName;
  final double totalAmount;
  final int itemCount;
  final String? note;
  final String? methodLabel;
  final String? createdAt;
  final String? paidAt;

  bool get isPaid => status == Status.paid;
  bool get isActive => status == Status.open || status == Status.waitPayment;
}

/// Tiền đã thu theo một hình thức thanh toán (Tiền mặt, Chuyển khoản…).
class MethodTotal {
  const MethodTotal({required this.method, required this.label, required this.count, required this.total});

  factory MethodTotal.fromJson(Map<String, dynamic> j) => MethodTotal(
        method: j['method'] as String,
        label: j['label'] as String,
        count: _int(j['count']),
        total: _money(j['total']),
      );

  final String method;
  final String label;
  final int count;
  final double total;
}

/// Đơn do người đang đăng nhập tạo trong một ngày + tổng kết.
class OrderHistory {
  const OrderHistory({
    required this.date,
    required this.orders,
    required this.paidCount,
    required this.paidTotal,
    required this.openCount,
    required this.openTotal,
    this.byMethod = const [],
  });

  factory OrderHistory.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] as Map<String, dynamic>;
    return OrderHistory(
      date: j['date'] as String,
      // Giờ tạo mới nhất lên đầu (sắp lại ở máy, kể cả khi máy chủ cũ trả theo thứ tự khác).
      orders: (j['orders'] as List).map((o) => HistoryOrder.fromJson(o as Map<String, dynamic>)).toList()
        ..sort((a, b) {
          final byTime = (b.createdAt ?? '').compareTo(a.createdAt ?? '');
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        }),
      paidCount: _int(s['paid_count']),
      paidTotal: _money(s['paid_total']),
      openCount: _int(s['open_count']),
      openTotal: _money(s['open_total']),
      byMethod: ((s['by_method'] as List?) ?? const [])
          .map((m) => MethodTotal.fromJson(m as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String date;
  final List<HistoryOrder> orders;
  final int paidCount;
  final double paidTotal;
  final int openCount;
  final double openTotal;

  /// Đã thu theo từng hình thức thanh toán.
  final List<MethodTotal> byMethod;
}
