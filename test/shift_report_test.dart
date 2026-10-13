import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/ticket.dart';
import 'package:leno_pos/printing/tickets.dart';

/// Báo cáo cuối ngày: đọc GET /reports/shift và phiếu in bàn giao ca.
void main() {
  final json = {
    'user': {'id': 1, 'username': 'lan', 'fullname': 'Nguyễn Thị Lan'},
    'device_name': 'Leno POS (android)',
    'login_at': '2026-10-13 07:02:11',
    'from': '2026-10-13 07:02:11',
    'to': '2026-10-13 17:30:00',
    'orders': {'count': 12, 'paid_count': 10, 'open_count': 1, 'open_total': 45000, 'cancelled_count': 1},
    'payments': {
      'count': 10,
      'total': 1250000,
      'by_method': [
        {'method': 'CASH', 'label': 'Tiền mặt', 'count': 7, 'total': 850000},
        {'method': 'TRANSFER', 'label': 'Chuyển khoản', 'count': 3, 'total': 400000},
      ],
    },
  };

  test('shift report parses from the API', () {
    final r = ShiftReport.fromJson(json);
    expect(r.fullname, 'Nguyễn Thị Lan');
    expect(r.orderCount, 12);
    expect(r.cancelledCount, 1);
    expect(r.totalOf('CASH'), 850000);
    expect(r.countOf('TRANSFER'), 3);
    expect(r.paymentTotal, 1250000);
    expect(r.totalOf('CARD'), 0);
  });

  test('printed shift report lists staff, time range, orders and money', () {
    final lines = Tickets.shiftReport(ShiftReport.fromJson(json), const ReceiptInfo(shopName: 'Leno')).lines;
    final rows = {for (final r in lines.whereType<TicketRow>()) r.left: r.right};
    expect(lines.whereType<TicketText>().map((t) => t.text), contains('BÁO CÁO CUỐI NGÀY'));
    expect(rows['Nhân viên'], 'Nguyễn Thị Lan');
    expect(rows['Từ'], '13/10/2026 07:02');
    expect(rows['Đến'], '13/10/2026 17:30');
    expect(rows['Số đơn'], '12');
    expect(rows['  Đã huỷ'], '1');
    expect(rows['Tiền mặt (7)'], '850.000');
    expect(rows['Chuyển khoản (3)'], '400.000');
    expect(rows['TỔNG THU'], '1.250.000');
  });
}
