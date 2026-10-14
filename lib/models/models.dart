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
  const ShopSettings({
    required this.siteName,
    required this.vatPercent,
    required this.takeawayEnabled,
    this.bankQr,
    this.receipt = const ReceiptInfo(),
  });

  factory ShopSettings.fromJson(Map<String, dynamic> j) {
    final siteName = (j['site_name'] as String?) ?? 'Leno';
    return ShopSettings(
      siteName: siteName,
      vatPercent: _money(j['vat_percent']),
      takeawayEnabled: j['takeaway_enabled'] == true,
      bankQr: j['bank_qr'] is Map<String, dynamic> ? BankQr.fromJson(j['bank_qr'] as Map<String, dynamic>) : null,
      // Máy chủ cũ chưa có "Thông tin in phiếu" -> dùng tên website và lời cảm ơn mặc định.
      receipt: j['receipt'] is Map<String, dynamic>
          ? ReceiptInfo.fromJson(j['receipt'] as Map<String, dynamic>)
          : ReceiptInfo(shopName: siteName),
    );
  }

  final String siteName;
  final double vatPercent;
  final bool takeawayEnabled;

  /// Tài khoản nhận chuyển khoản (Cài đặt trên web) — null khi máy chủ chưa có tính năng này.
  final BankQr? bankQr;

  /// Tên quán, địa chỉ, SĐT, lời cảm ơn in trên phiếu (web: Cài đặt → Thông tin in phiếu).
  final ReceiptInfo receipt;
}

/// Thông tin cửa hàng in trên phiếu tạm tính / phiếu tính tiền — quản lý chung trên web.
class ReceiptInfo {
  const ReceiptInfo({
    this.shopName = 'Leno',
    this.address = '',
    this.phone = '',
    this.footer = 'Cảm ơn quý khách - Hẹn gặp lại!',
  });

  factory ReceiptInfo.fromJson(Map<String, dynamic> j) => ReceiptInfo(
        shopName: (j['shop_name'] as String?) ?? 'Leno',
        address: (j['address'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        footer: (j['footer'] as String?) ?? '',
      );

  final String shopName;
  final String address;
  final String phone;
  final String footer;
}

/// Tài khoản nhận chuyển khoản để in mã VietQR trên phiếu tạm tính.
class BankQr {
  const BankQr({
    required this.enabled,
    required this.bin,
    required this.bankName,
    required this.accountNo,
    this.accountName = '',
  });

  factory BankQr.fromJson(Map<String, dynamic> j) => BankQr(
        enabled: j['enabled'] == true,
        bin: (j['bin'] as String?) ?? '',
        bankName: (j['bank_name'] as String?) ?? '',
        accountNo: (j['account_no'] as String?) ?? '',
        accountName: (j['account_name'] as String?) ?? '',
      );

  /// Bật in QR và đã có đủ ngân hàng + số tài khoản.
  final bool enabled;

  /// Mã BIN ngân hàng của NAPAS, vd 970415 = VietinBank.
  final String bin;
  final String bankName;
  final String accountNo;
  final String accountName;
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
    this.priceBookId,
    this.priceBookName,
    this.discountId,
    this.discountName,
    this.discountMinOrder,
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
        priceBookId: _intOrNull(j['price_book_id']),
        priceBookName: _str(j['price_book_name']),
        discountId: _intOrNull(j['discount_id']),
        discountName: _str(j['discount_name']),
        discountMinOrder: j['discount_min_order'] == null ? null : _money(j['discount_min_order']),
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

  /// Bảng giá người bán chọn cho đơn (null = giá gốc); tên lưu lại để in hóa đơn.
  final int? priceBookId;
  final String? priceBookName;

  /// Khuyến mãi trên tổng đơn người bán chọn (null = không). [discountAmount] = số tiền đang được giảm
  /// (0 khi tạm tính chưa đủ [discountMinOrder]).
  final int? discountId;
  final String? discountName;
  final double? discountMinOrder;

  bool get hasDiscount => discountId != null || (discountName ?? '').isNotEmpty;

  /// Còn thiếu bao nhiêu để khuyến mãi đã chọn được áp (0 = đã giảm / không có khuyến mãi).
  double get discountShortOf =>
      hasDiscount && discountAmount <= 0 ? ((discountMinOrder ?? 0) - subtotal).clamp(0, double.infinity).toDouble() : 0;
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
    this.originalPrice,
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
        originalPrice: j['original_price'] == null ? null : _money(j['original_price']),
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

  /// Giá gốc khi bán theo bảng giá (null = bán đúng giá gốc) — hiện gạch ngang cạnh giá mới.
  final double? originalPrice;

  bool get isCancelled => status == Status.cancelled;

  /// Bán theo bảng giá với giá khác giá gốc.
  bool get hasOffer => originalPrice != null && originalPrice != price;
}

/// Bảng giá có hiệu lực hôm nay (GET /price-books): người bán tự chọn cho đơn, không tự áp.
class PriceBook {
  const PriceBook({required this.id, required this.name, required this.prices});

  factory PriceBook.fromJson(Map<String, dynamic> j) => PriceBook(
        id: _int(j['id']),
        name: j['name'] as String,
        prices: {
          for (final e in ((j['prices'] as Map?) ?? const {}).entries) int.parse('${e.key}'): _money(e.value),
        },
      );

  final int id;
  final String name;

  /// product_id => giá mới; món không có = giữ giá gốc.
  final Map<int, double> prices;

  /// Giá bán của [p] theo bảng giá này.
  double priceOf(Product p) => prices[p.id] ?? p.price;
}

/// Khuyến mãi trên tổng đơn có hiệu lực hôm nay (GET /discounts): giảm % (giới hạn tối đa tuỳ chọn) hoặc số tiền,
/// cho đơn từ [minOrder]. Người bán tự chọn cho đơn, không tự áp; máy chủ tính số tiền giảm.
class Discount {
  const Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrder = 0,
    this.description = '',
  });

  factory Discount.fromJson(Map<String, dynamic> j) => Discount(
        id: _int(j['id']),
        name: j['name'] as String,
        type: (j['type'] as String?) ?? 'PERCENT',
        value: _money(j['value']),
        maxDiscount: j['max_discount'] == null ? null : _money(j['max_discount']),
        minOrder: _money(j['min_order']),
        description: (j['description'] as String?) ?? '',
      );

  final int id;
  final String name;

  /// PERCENT | AMOUNT.
  final String type;
  final double value;
  final double? maxDiscount;
  final double minOrder;

  /// Mô tả từ máy chủ, vd "Giảm 15% (tối đa 50.000) · đơn từ 500.000".
  final String description;

  /// Tên ngắn trong ô chọn (giống web): "Giảm 10% · từ 500K".
  String get shortLabel {
    if (minOrder <= 0) return name;
    // Nghìn đồng, nhóm 3 chữ số bằng dấu chấm (1.500K) — giống number_format trên web.
    final k = (minOrder / 1000).round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$name · từ ${k}K';
  }
}

/// Bảng giá + khuyến mãi chọn ở Sơ đồ bàn (GET / POST /offers), dùng chung mọi máy: áp cho mọi đơn đang mở
/// và bàn mở sau. Lựa chọn hết hiệu lực (sang ngày / thứ khác, bị tắt) máy chủ coi như không chọn.
class ShopOffers {
  const ShopOffers({
    this.priceBookId,
    this.priceBookName,
    this.discount,
    this.priceBooks = const [],
    this.discounts = const [],
    this.appliedCount = 0,
  });

  factory ShopOffers.fromJson(Map<String, dynamic> j) {
    final book = j['price_book'] as Map<String, dynamic>?;
    return ShopOffers(
      priceBookId: book == null ? null : _int(book['id']),
      priceBookName: book?['name'] as String?,
      discount: j['discount'] is Map<String, dynamic> ? Discount.fromJson(j['discount'] as Map<String, dynamic>) : null,
      priceBooks: [for (final b in (j['price_books'] as List?) ?? const []) PriceBook.fromJson(b as Map<String, dynamic>)],
      discounts: [for (final d in (j['discounts'] as List?) ?? const []) Discount.fromJson(d as Map<String, dynamic>)],
      appliedCount: _intOrNull(j['applied_count']) ?? 0,
    );
  }

  final int? priceBookId;
  final String? priceBookName;
  final Discount? discount;

  /// Lựa chọn có hiệu lực hôm nay.
  final List<PriceBook> priceBooks;
  final List<Discount> discounts;

  /// Số đơn đang mở vừa được áp (chỉ có sau POST).
  final int appliedCount;

  /// Hôm nay có gì để chọn, hoặc đang chọn — không thì ẩn hàng chọn trên Sơ đồ bàn.
  bool get isRelevant => priceBooks.isNotEmpty || discounts.isNotEmpty || priceBookId != null || discount != null;
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
/// Hình thức thanh toán — chỉ Tiền mặt và Chuyển khoản (giống web, máy chủ từ chối mã khác).
enum PaymentMethod {
  cash('CASH', 'Tiền mặt'),
  transfer('TRANSFER', 'Chuyển khoản');

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

/// Phiếu thu (sổ quỹ) do nhân viên lập trên ứng dụng — mã PT000001...
class CashReceipt {
  const CashReceipt({
    required this.id,
    required this.entryNo,
    required this.entryDate,
    required this.paymentMethod,
    required this.methodLabel,
    required this.amount,
    this.categoryName,
    this.counterparty,
    this.handledName,
    this.note,
  });

  factory CashReceipt.fromJson(Map<String, dynamic> j) => CashReceipt(
        id: _int(j['id']),
        entryNo: j['entry_no'] as String,
        entryDate: j['entry_date'] as String,
        paymentMethod: j['payment_method'] as String,
        methodLabel: (j['method_label'] as String?) ?? '',
        amount: _money(j['amount']),
        categoryName: _str(j['category_name']),
        counterparty: _str(j['counterparty']),
        handledName: _str(j['handled_name']),
        note: _str(j['note']),
      );

  final int id;
  final String entryNo;

  /// "Y-m-d H:i:s" theo giờ máy chủ.
  final String entryDate;
  final String paymentMethod;
  final String methodLabel;
  final double amount;
  final String? categoryName;

  /// Người nộp tiền.
  final String? counterparty;

  /// Nhân viên thu.
  final String? handledName;
  final String? note;
}

/// Dữ liệu màn hình "Lập phiếu thu" (GET /cashbook/receipts): loại thu, tên người nộp đã dùng, phiếu đã lập hôm nay.
class CashReceiptsData {
  const CashReceiptsData({this.categories = const [], this.counterparties = const [], this.receipts = const []});

  factory CashReceiptsData.fromJson(Map<String, dynamic> j) => CashReceiptsData(
        categories: [
          for (final c in (j['categories'] as List?) ?? const [])
            (id: _int((c as Map<String, dynamic>)['id']), name: c['name'] as String),
        ],
        counterparties: [for (final s in (j['counterparties'] as List?) ?? const []) s as String],
        receipts: [for (final r in (j['receipts'] as List?) ?? const []) CashReceipt.fromJson(r as Map<String, dynamic>)],
      );

  final List<({int id, String name})> categories;
  final List<String> counterparties;
  final List<CashReceipt> receipts;

  double get total => receipts.fold(0, (s, r) => s + r.amount);
}

/// Báo cáo cuối ngày (GET /reports/shift) của người đang đăng nhập: từ lúc đăng nhập trên máy này (hoặc 00:00 hôm nay)
/// tới lúc xem — số đơn đã tạo theo trạng thái và tiền đã thu theo hình thức.
class ShiftReport {
  const ShiftReport({
    required this.fullname,
    required this.username,
    required this.from,
    required this.to,
    this.loginAt,
    this.deviceName,
    this.orderCount = 0,
    this.paidCount = 0,
    this.openCount = 0,
    this.openTotal = 0,
    this.cancelledCount = 0,
    this.paymentCount = 0,
    this.paymentTotal = 0,
    this.byMethod = const [],
    this.receiptCount = 0,
    this.receiptTotal = 0,
    this.receiptsByMethod = const [],
  });

  factory ShiftReport.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>;
    final orders = (j['orders'] as Map<String, dynamic>?) ?? const {};
    final payments = (j['payments'] as Map<String, dynamic>?) ?? const {};
    final receipts = (j['receipts'] as Map<String, dynamic>?) ?? const {};
    return ShiftReport(
      fullname: (user['fullname'] as String?) ?? '',
      username: (user['username'] as String?) ?? '',
      from: j['from'] as String,
      to: j['to'] as String,
      loginAt: _str(j['login_at']),
      deviceName: _str(j['device_name']),
      orderCount: _intOrNull(orders['count']) ?? 0,
      paidCount: _intOrNull(orders['paid_count']) ?? 0,
      openCount: _intOrNull(orders['open_count']) ?? 0,
      openTotal: _money(orders['open_total']),
      cancelledCount: _intOrNull(orders['cancelled_count']) ?? 0,
      paymentCount: _intOrNull(payments['count']) ?? 0,
      paymentTotal: _money(payments['total']),
      byMethod: [
        for (final m in (payments['by_method'] as List?) ?? const []) MethodTotal.fromJson(m as Map<String, dynamic>),
      ],
      receiptCount: _intOrNull(receipts['count']) ?? 0,
      receiptTotal: _money(receipts['total']),
      receiptsByMethod: [
        for (final m in (receipts['by_method'] as List?) ?? const []) MethodTotal.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  final String fullname;
  final String username;

  /// "Y-m-d H:i:s" theo giờ máy chủ.
  final String from;
  final String to;
  final String? loginAt;
  final String? deviceName;

  /// Đơn người này tạo trong khoảng (không tính đơn chưa có món).
  final int orderCount;
  final int paidCount;
  final int openCount;
  final double openTotal;
  final int cancelledCount;

  /// Tiền người này đã thu (thanh toán do người này xác nhận).
  final int paymentCount;
  final double paymentTotal;
  final List<MethodTotal> byMethod;

  /// Phiếu thu (sổ quỹ) người này thu trong khoảng — máy chủ cũ không gửi thì 0.
  final int receiptCount;
  final double receiptTotal;
  final List<MethodTotal> receiptsByMethod;

  /// Tiền bán hàng theo hình thức.
  double totalOf(String method) => byMethod.where((m) => m.method == method).firstOrNull?.total ?? 0;
  int countOf(String method) => byMethod.where((m) => m.method == method).firstOrNull?.count ?? 0;

  /// Phiếu thu theo hình thức.
  double receiptTotalOf(String method) => receiptsByMethod.where((m) => m.method == method).firstOrNull?.total ?? 0;
  int receiptCountOf(String method) => receiptsByMethod.where((m) => m.method == method).firstOrNull?.count ?? 0;

  /// Cả bán hàng + phiếu thu theo hình thức (vd tiền mặt phải có trong két).
  double allOf(String method) => totalOf(method) + receiptTotalOf(method);

  /// Tổng thu = bán hàng + phiếu thu.
  double get grandTotal => paymentTotal + receiptTotal;
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
