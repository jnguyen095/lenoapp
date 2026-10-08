import 'package:flutter/painting.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'print_settings.dart';
import 'ticket.dart';

/// Mẫu phiếu in — cùng nội dung với mẫu K80 trên web (views/orders/*.php).
class Tickets {
  Tickets._();

  /// Phiếu bếp cho phần vừa báo (đã tách theo máy in). [station] = tên máy in, vd "Quầy bar".
  static Ticket kitchen(KitchenSlip slip, Order order, {String? station}) {
    // Cùng bố cục với phiếu tính tiền: khung tên bàn | Số HĐ + Thời gian, bảng món có tiêu đề cột,
    // ghi chú món trong ngoặc sau tên món.
    const flex = [80.0, 20.0];
    const aligns = [TextAlign.left, TextAlign.center];
    const header = TicketColumns(['Tên món', 'SL'], flex: flex, aligns: aligns, bold: true);
    // Ghi chú món in nghiêng sau tên món, vd: Cà phê sữa đá *(Ít đá)*.
    TicketColumns row(String name, int qty, {String? note}) =>
        TicketColumns([name, '$qty'], flex: flex, aligns: aligns, notes: [note, null]);

    final lines = <TicketLine>[
      const TicketText('PHIẾU BẾP', align: TextAlign.center, scale: 1.2, bold: true),
      if (station != null) TicketText(station, align: TextAlign.center),
      if ((slip.staff ?? '').isNotEmpty) TicketText('Nhân viên: ${slip.staff}', align: TextAlign.center),
      const TicketDivider(),
      TicketBoxSplit(order.tableId == null ? 'Mang đi' : order.tableName, [
        'Số HĐ: ${order.orderNo}',
        'Thời gian: ${formatDateTime(slip.createdAt)}',
      ], note: (slip.orderNote ?? '').isEmpty ? null : 'Ghi chú: ${slip.orderNote}'),
      const TicketDivider(),
    ];

    if (slip.send.isNotEmpty) {
      lines.add(header);
      for (final l in slip.send) {
        lines.add(row(l.productName, l.qty, note: l.note));
      }
    }
    if (slip.changed.isNotEmpty) {
      if (slip.send.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('ĐỔI GHI CHÚ', bold: true));
      lines.add(header);
      for (final l in slip.changed) {
        lines.add(row(l.productName, l.qty, note: (l.note ?? '').isEmpty ? 'bỏ ghi chú' : l.note));
      }
    }
    if (slip.cancel.isNotEmpty) {
      if (slip.send.isNotEmpty || slip.changed.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('HỦY MÓN', bold: true));
      lines.add(header);
      for (final l in slip.cancel) {
        lines.add(row(l.productName, l.qty));
      }
    }
    return Ticket(lines);
  }

  /// Phiếu tạm tính (đơn đang mở) hoặc hóa đơn bán hàng (đơn đã thanh toán).
  static Ticket bill(OrderDetail detail, PrintSettings settings) {
    final order = detail.order;
    final paid = order.status == Status.paid;
    final items = detail.items.where((i) => !i.isCancelled);
    final payment = detail.payment;
    String money(double v) => formatMoney(v, withUnit: false);

    // Bảng món 4 cột: Tên món | Đ.Giá | SL | Tiền.
    const flex = [46.0, 21.0, 9.0, 24.0];
    const aligns = [TextAlign.left, TextAlign.right, TextAlign.center, TextAlign.right];

    return Ticket([
      if (settings.shopName.isNotEmpty) TicketText(settings.shopName, align: TextAlign.center, scale: 1.4, bold: true),
      if (settings.shopAddress.isNotEmpty) TicketText(settings.shopAddress, align: TextAlign.center),
      if (settings.shopPhone.isNotEmpty) TicketText('ĐT: ${settings.shopPhone}', align: TextAlign.center),
      TicketText(paid ? 'PHIẾU TÍNH TIỀN' : 'PHIẾU TẠM TÍNH', align: TextAlign.center, scale: 1.2, bold: true),
      if ((order.createdByName ?? '').isNotEmpty)
        TicketText('Nhân viên: ${order.createdByName}', align: TextAlign.center),
      const TicketDivider(),
      // Trái (30): tên bàn trong khung bo góc — phải (60): Số HĐ + Thời gian.
      TicketBoxSplit(order.tableId == null ? 'Mang đi' : order.tableName, [
        paid ? 'Số HĐ: ${order.orderNo}' : 'Mã đơn: ${order.orderNo}',
        'Thời gian: ${formatDateTime(paid ? order.paidAt : null)}',
      ], note: !paid && (order.note ?? '').isNotEmpty ? 'Ghi chú: ${order.note}' : null),
      const TicketDivider(),
      const TicketColumns(['Tên món', 'Đ.Giá', 'SL', 'Tiền'], flex: flex, aligns: aligns, bold: true),
      for (final it in items)
        TicketColumns(
          [it.productName, money(it.price), '${it.qty}', money(it.amount)],
          // Phiếu tạm tính: ghi chú món in nghiêng sau tên món (hóa đơn đã thanh toán thì không in).
          notes: [paid ? null : it.note, null, null, null],
          flex: flex,
          aligns: aligns,
        ),
      const TicketDivider(),
      TicketRow('Tạm tính', money(order.subtotal)),
      TicketRow('Chiết khấu', order.discountAmount > 0 ? '-${money(order.discountAmount)}' : '0'),
      if (order.vatAmount > 0) TicketRow('VAT', money(order.vatAmount)),
      TicketRow('TỔNG CỘNG', money(order.totalAmount), bold: true),
      if (paid && payment != null) TicketRow('Hình thức TT', payment.methodLabel),
      const TicketDivider(),
      TicketText(
        paid ? settings.footer : '-- Phiếu tạm tính, chưa phải hóa đơn --',
        align: TextAlign.center,
      ),
    ]);
  }

  /// Trang in thử khi cài máy in.
  static Ticket test(PrinterConfig printer, {Map<int, String> categoryNames = const {}}) {
    final cats = printer.categoryIds.map((id) => categoryNames[id] ?? '#$id').toList()..sort();
    return Ticket([
      const TicketText('IN THỬ', align: TextAlign.center, scale: 1.5, bold: true),
      TicketText(printer.name, align: TextAlign.center, scale: 1.2),
      const TicketDivider(),
      TicketText('Địa chỉ: ${printer.address}'),
      TicketText('Khổ giấy: ${printer.paper.label}'),
      TicketText('Hóa đơn / tạm tính: ${printer.receipts ? 'Có' : 'Không'}'),
      TicketText('Máy bếp mặc định: ${printer.kitchenDefault ? 'Có' : 'Không'}'),
      TicketText('Danh mục: ${cats.isEmpty ? '(chưa chọn)' : cats.join(', ')}'),
      const TicketDivider(),
      const TicketText('Tiếng Việt: Cà phê sữa đá, Trà đào cam sả, Bánh mì ốp la', italic: true),
      TicketText('Giờ in: ${formatDateTime(null)}', align: TextAlign.center),
    ]);
  }
}

/// Kết quả tách phiếu bếp: phiếu riêng cho từng máy in + món không có máy nào nhận.
class KitchenRoute {
  const KitchenRoute(this.jobs, this.unrouted);

  final List<(PrinterConfig, KitchenSlip)> jobs;
  final List<SlipLine> unrouted;
}

/// Món thuộc danh mục gán cho máy nào thì in ra máy đó (một danh mục có thể in ra nhiều máy);
/// danh mục chưa gán máy nào -> các máy "Máy bếp mặc định".
KitchenRoute routeKitchenSlip(KitchenSlip slip, Iterable<PrinterConfig> printers, int? Function(int productId) categoryOf) {
  final active = printers.where((p) => p.enabled).toList();
  final defaults = active.where((p) => p.kitchenDefault).toList();

  List<PrinterConfig> targets(SlipLine line) {
    final cat = categoryOf(line.productId);
    final assigned = cat == null ? const <PrinterConfig>[] : active.where((p) => p.categoryIds.contains(cat)).toList();
    return assigned.isNotEmpty ? assigned : defaults;
  }

  final jobs = <(PrinterConfig, KitchenSlip)>[];
  for (final p in active) {
    final part = slip.where((l) => targets(l).any((t) => t.id == p.id));
    if (!part.isEmpty) jobs.add((p, part));
  }

  final unrouted = [...slip.send, ...slip.cancel, ...slip.changed].where((l) => targets(l).isEmpty).toList();
  return KitchenRoute(jobs, unrouted);
}
