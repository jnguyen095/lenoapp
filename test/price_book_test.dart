import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/ticket.dart';
import 'package:leno_pos/printing/tickets.dart';

/// Bảng giá: đọc dữ liệu máy chủ (GET /price-books, đơn / món kèm giá gốc) và in giá cũ / giá mới trên hóa đơn
/// (không in tên bảng giá).
void main() {
  test('price book and order fields parse from the API', () {
    final book = PriceBook.fromJson({'id': 3, 'name': 'Giá cuối tuần', 'prices': {'77': 12000, '82': 11000.0}});
    expect(book.prices, {77: 12000.0, 82: 11000.0});
    const pepsi = Product(id: 77, categoryId: 1, sku: 'NU-01', name: 'Pepsi', price: 15000);
    const tea = Product(id: 92, categoryId: 1, sku: 'TR-01', name: 'Trà', price: 20000);
    expect(book.priceOf(pepsi), 12000);
    expect(book.priceOf(tea), 20000, reason: 'món không có trong bảng giá giữ giá gốc');

    final order = Order.fromJson({
      'id': 1, 'order_no': 'ORD1', 'order_type': 'DINE_IN', 'status': 'OPEN', 'table_name': 'Bàn 2',
      'subtotal': 0, 'discount_amount': 0, 'vat_amount': 0, 'total_amount': 0,
      'price_book_id': 3, 'price_book_name': 'Giá cuối tuần',
    });
    expect(order.priceBookId, 3);
    expect(order.priceBookName, 'Giá cuối tuần');

    // Máy chủ cũ không gửi các trường mới -> giá gốc.
    final legacy = OrderItem.fromJson({
      'id': 1, 'product_id': 77, 'product_name': 'Pepsi', 'qty': 1, 'notified_qty': 0,
      'price': 15000, 'amount': 15000, 'status': 'ACTIVE',
    });
    expect(legacy.originalPrice, isNull);
    expect(legacy.hasOffer, isFalse);
  });

  test('bill shows struck original prices and the amount saved, not the price book name', () {
    OrderItem item(int id, String name, double price, double? original, int qty) => OrderItem(
          id: id, productId: id, productName: name, image: null, qty: qty, notifiedQty: qty, price: price,
          amount: price * qty, note: null, notifiedNote: null, status: 'ACTIVE', pending: false, originalPrice: original,
        );
    final detail = OrderDetail(
      order: const Order(
        id: 85, orderNo: 'ORD261012-PB', orderType: 'DINE_IN', status: 'OPEN', note: null, tableId: 2,
        tableName: 'Bàn 2', tableNote: null, createdByName: 'Lan', subtotal: 67000, discountAmount: 0,
        vatAmount: 0, totalAmount: 67000, createdAt: null, paidAt: null, priceBookId: 3, priceBookName: 'Giá cuối tuần',
      ),
      isActive: true,
      items: [
        item(1, 'Pepsi', 12000, 15000, 3), // giảm 3.000 x 3
        item(2, 'Xúc xích', 11000, 10000, 1), // tăng giá: không tính vào "tiết kiệm"
        item(3, 'Trà', 20000, null, 1),
      ],
      pendingCount: 0,
    );

    final lines = Tickets.bill(detail, const ReceiptInfo(shopName: 'Leno')).lines;

    final header = lines.whereType<TicketBoxSplit>().single;
    expect(header.lines.any((l) => l.startsWith('Bảng giá')), isFalse, reason: 'không in tên bảng giá trên hóa đơn');

    final struck = lines.whereType<TicketColumns>().where((c) => c.strike).map((c) => c.cells[1]).toList();
    expect(struck, ['15.000', '10.000'], reason: 'giá gốc gạch ngang dưới các món bán theo bảng giá');

    final saved = lines.whereType<TicketRow>().where((r) => r.left == 'Bạn đã tiết kiệm').single;
    expect(saved.right, '9.000');
  });

  test('bill without a price book has no price book lines', () {
    const detail = OrderDetail(
      order: Order(
        id: 86, orderNo: 'ORD2', orderType: 'DINE_IN', status: 'OPEN', note: null, tableId: 2, tableName: 'Bàn 2',
        tableNote: null, createdByName: null, subtotal: 20000, discountAmount: 0, vatAmount: 0, totalAmount: 20000,
        createdAt: null, paidAt: null,
      ),
      isActive: true,
      items: [
        OrderItem(id: 3, productId: 3, productName: 'Trà', image: null, qty: 1, notifiedQty: 1, price: 20000,
            amount: 20000, note: null, notifiedNote: null, status: 'ACTIVE', pending: false),
      ],
      pendingCount: 0,
    );
    final lines = Tickets.bill(detail, const ReceiptInfo(shopName: 'Leno')).lines;
    expect(lines.whereType<TicketBoxSplit>().single.lines.any((l) => l.startsWith('Bảng giá')), isFalse);
    expect(lines.whereType<TicketColumns>().any((c) => c.strike), isFalse);
    expect(lines.whereType<TicketRow>().any((r) => r.left == 'Bạn đã tiết kiệm'), isFalse);
  });

  // ---- Khuyến mãi trên tổng đơn (cùng hàng với bảng giá) ----

  Order discounted({required double subtotal, required double discount, double minOrder = 100000}) => Order(
        id: 87, orderNo: 'ORD3', orderType: 'DINE_IN', status: 'OPEN', note: null, tableId: 2, tableName: 'Bàn 2',
        tableNote: null, createdByName: null, subtotal: subtotal, discountAmount: discount, vatAmount: 0,
        totalAmount: subtotal - discount, createdAt: null, paidAt: null,
        discountId: 2, discountName: 'Giảm 10%', discountMinOrder: minOrder,
      );

  test('discount and order discount fields parse from the API', () {
    final d = Discount.fromJson({
      'id': 2, 'name': 'Giảm 10%', 'type': 'PERCENT', 'value': 10, 'max_discount': 50000, 'min_order': 1500000,
      'description': 'Giảm 10% (tối đa 50.000) · đơn từ 1.500.000',
    });
    expect(d.maxDiscount, 50000);
    expect(d.shortLabel, 'Giảm 10% · từ 1.500K', reason: 'giống ô chọn trên web');
    expect(Discount.fromJson({'id': 3, 'name': 'Giảm 5k', 'type': 'AMOUNT', 'value': 5000}).shortLabel, 'Giảm 5k');

    final o = Order.fromJson({
      'id': 1, 'order_no': 'ORD1', 'order_type': 'DINE_IN', 'status': 'OPEN', 'table_name': 'Bàn 2',
      'subtotal': 80000, 'discount_amount': 0, 'vat_amount': 0, 'total_amount': 80000,
      'discount_id': 2, 'discount_name': 'Giảm 10%', 'discount_min_order': 100000,
    });
    expect(o.hasDiscount, isTrue);
    expect(o.discountMinOrder, 100000);
  });

  test('chosen discount below the minimum order tells how much more to buy', () {
    expect(discounted(subtotal: 80000, discount: 0).discountShortOf, 20000, reason: 'Mua thêm 20.000 để được giảm');
    expect(discounted(subtotal: 120000, discount: 12000).discountShortOf, 0, reason: 'Đã giảm 12.000');
    const none = Order(
      id: 1, orderNo: 'O', orderType: 'DINE_IN', status: 'OPEN', note: null, tableId: 1, tableName: 'Bàn 1',
      tableNote: null, createdByName: null, subtotal: 0, discountAmount: 0, vatAmount: 0, totalAmount: 0,
      createdAt: null, paidAt: null,
    );
    expect(none.hasDiscount, isFalse);
    expect(none.discountShortOf, 0);
  });

  test('bill names the discount and counts it in the amount saved', () {
    final detail = OrderDetail(
      order: discounted(subtotal: 120000, discount: 12000),
      isActive: true,
      items: const [
        OrderItem(id: 1, productId: 77, productName: 'Pepsi', image: null, qty: 10, notifiedQty: 10, price: 12000,
            amount: 120000, note: null, notifiedNote: null, status: 'ACTIVE', pending: false, originalPrice: 15000),
      ],
      pendingCount: 0,
    );
    final rows = Tickets.bill(detail, const ReceiptInfo(shopName: 'Leno')).lines.whereType<TicketRow>().toList();
    expect(rows.map((r) => r.left), containsAllInOrder(['Tạm tính', 'Chiết khấu (Giảm 10%)', 'TỔNG CỘNG']));
    expect(rows.firstWhere((r) => r.left.startsWith('Chiết khấu')).right, '-12.000');
    // 3.000 x 10 theo bảng giá + 12.000 khuyến mãi.
    expect(rows.firstWhere((r) => r.left == 'Bạn đã tiết kiệm').right, '42.000');

    // Chưa đủ đơn tối thiểu: giảm 0, không ghi tên khuyến mãi.
    final waiting = OrderDetail(order: discounted(subtotal: 80000, discount: 0), isActive: true, items: const [], pendingCount: 0);
    final waitingRows = Tickets.bill(waiting, const ReceiptInfo(shopName: 'Leno')).lines.whereType<TicketRow>();
    expect(waitingRows.firstWhere((r) => r.left.startsWith('Chiết khấu')).left, 'Chiết khấu');
  });

  test('shop offers chosen on the table map parse from GET / POST /offers', () {
    final o = ShopOffers.fromJson({
      'price_book': {'id': 6, 'name': 'Giảm 20%'},
      'discount': {'id': 1, 'name': 'Giảm 10%', 'type': 'PERCENT', 'value': 10, 'min_order': 100000,
          'description': 'Giảm 10% · đơn từ 100.000'},
      'price_books': [
        {'id': 6, 'name': 'Giảm 20%', 'prices': {'77': 12000}},
      ],
      'discounts': [
        {'id': 1, 'name': 'Giảm 10%', 'type': 'PERCENT', 'value': 10, 'min_order': 100000},
      ],
      'applied_count': 3,
    });
    expect(o.priceBookId, 6);
    expect(o.discount?.description, 'Giảm 10% · đơn từ 100.000');
    expect(o.priceBooks.single.prices, {77: 12000.0});
    expect(o.appliedCount, 3);
    expect(o.isRelevant, isTrue);

    // Không chọn gì và hôm nay không có bảng giá / khuyến mãi -> ẩn hàng chọn trên Sơ đồ bàn.
    final empty = ShopOffers.fromJson({'price_book': null, 'discount': null, 'price_books': [], 'discounts': []});
    expect(empty.isRelevant, isFalse);
    expect(empty.appliedCount, 0);
  });
}
