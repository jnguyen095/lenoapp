import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/core/api_client.dart';
import 'package:leno_pos/core/format.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/ui/widgets/payment_sheet.dart';

void main() {
  test('formatMoney uses dot thousands separators', () {
    expect(formatMoney(0), '0');
    expect(formatMoney(45000), '45.000');
    expect(formatMoney(1234567, withUnit: false), '1.234.567');
    expect(formatMoney(-20000), '-20.000');
  });

  test('foldVietnamese strips diacritics', () {
    expect(foldVietnamese('Cà phê sữa đá'), 'ca phe sua da');
    expect(foldVietnamese('TRÀ ĐÀO'), 'tra dao');
  });

  test('normalizeServerUrl', () {
    expect(ApiClient.normalizeServerUrl('leno.pickangelpark.com/'), 'https://leno.pickangelpark.com');
    expect(ApiClient.normalizeServerUrl(' http://192.168.1.10/leno// '), 'http://192.168.1.10/leno');
  });

  test('suggestedCash rounds up to common notes', () {
    expect(suggestedCash(38000), [38000, 40000, 50000, 100000, 200000, 500000]);
    expect(suggestedCash(50000).first, 50000);
  });

  test('OrderDetail parses API payload', () {
    final detail = OrderDetail.fromJson({
      'success': true,
      'order': {
        'id': 80, 'order_no': 'ORD261007-0093D', 'order_type': 'DINE_IN', 'status': 'OPEN', 'note': null,
        'table_id': 21, 'table_name': 'Bàn 1', 'table_note': null, 'created_by_name': 'Lan',
        'subtotal': 58000, 'discount_amount': 0, 'vat_amount': 0, 'total_amount': 58000,
        'created_at': '2026-10-07 09:19:09', 'paid_at': null,
      },
      'is_active': true,
      'items': [
        {
          'id': 182, 'product_id': 103, 'product_name': 'Espresso sữa đá', 'image': null, 'qty': 2,
          'notified_qty': 1, 'price': 20000, 'amount': 40000, 'note': 'Ít đá', 'notified_note': null,
          'status': 'ACTIVE', 'pending': true,
        },
        {
          'id': 184, 'product_id': 105, 'product_name': 'Phin sữa nóng', 'image': 'assets/uploads/p.jpg', 'qty': 1,
          'notified_qty': 1, 'price': 18000, 'amount': 18000, 'note': null, 'notified_note': null,
          'status': 'ACTIVE', 'pending': false,
        },
      ],
      'pending_count': 1,
      'payment': null,
    });

    expect(detail.order.totalAmount, 58000);
    expect(detail.items.first.pending, isTrue);
    expect(detail.qtyOfProduct(103), 2);
    expect(detail.activeItemCount, 3);
    expect(detail.payment, isNull);
  });
}
