import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/ticket.dart';
import 'package:leno_pos/printing/tickets.dart';

/// Bảng giá: đọc dữ liệu máy chủ (GET /price-books, đơn / món kèm giá gốc) và in giá cũ / giá mới trên hóa đơn.
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

  test('bill shows the price book, struck original prices and the amount saved', () {
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
    expect(header.lines, contains('Bảng giá: Giá cuối tuần'));

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
}
