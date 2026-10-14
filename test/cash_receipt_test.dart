import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/ticket.dart';
import 'package:leno_pos/printing/tickets.dart';

/// Sổ quỹ — lập phiếu thu trên ứng dụng: đọc GET /cashbook/receipts và phiếu in.
void main() {
  final json = {
    'categories': [
      {'id': 1, 'name': 'Thu khác'},
      {'id': 3, 'name': 'Thu nợ'},
    ],
    'counterparties': ['Anh Nam', 'Chị Hoa'],
    'receipts': [
      {
        'id': 7, 'entry_no': 'PT000003', 'entry_date': '2026-10-14 08:52:07', 'payment_method': 'CASH',
        'method_label': 'Tiền mặt', 'category_name': 'Thu nợ', 'counterparty': 'Anh Nam', 'handled_name': 'Lan',
        'amount': 150000, 'note': 'Trả nợ tuần trước',
      },
      {
        'id': 8, 'entry_no': 'PT000004', 'entry_date': '2026-10-14 09:10:00', 'payment_method': 'TRANSFER',
        'method_label': 'Chuyển khoản', 'category_name': 'Thu khác', 'counterparty': null, 'handled_name': 'Lan',
        'amount': 20000, 'note': null,
      },
    ],
  };

  test('receipts screen data parses from the API', () {
    final d = CashReceiptsData.fromJson(json);
    expect(d.categories.map((c) => c.name), ['Thu khác', 'Thu nợ']);
    expect(d.counterparties, ['Anh Nam', 'Chị Hoa']);
    expect(d.receipts.first.entryNo, 'PT000003');
    expect(d.receipts.last.counterparty, isNull);
    expect(d.total, 170000);
  });

  test('printed receipt has number, payer, method, amount and signatures', () {
    final r = CashReceiptsData.fromJson(json).receipts.first;
    final lines = Tickets.cashReceipt(r, const ReceiptInfo(shopName: 'Leno')).lines;
    final texts = lines.whereType<TicketText>().map((t) => t.text).toList();
    // Dòng đầu tiên của mỗi nhãn (dòng ký tên cuối phiếu cũng bắt đầu bằng "Người nộp").
    final rows = <String, String>{};
    for (final row in lines.whereType<TicketRow>()) {
      rows.putIfAbsent(row.left, () => row.right);
    }
    expect(texts, containsAll(['PHIẾU THU', 'Số: PT000003', 'Ghi chú: Trả nợ tuần trước']));
    expect(rows['Thời gian'], '14/10/2026 08:52');
    expect(rows['Loại thu'], 'Thu nợ');
    expect(rows['Người nộp'], 'Anh Nam');
    expect(rows['Hình thức'], 'Tiền mặt');
    expect(rows['SỐ TIỀN'], '150.000');
  });
}
