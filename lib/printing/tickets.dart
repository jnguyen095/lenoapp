import 'package:flutter/painting.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'print_settings.dart';
import 'ticket.dart';

/// Mẫu phiếu in — cùng nội dung với mẫu K80 trên web (views/orders/*.php).
class Tickets {
  Tickets._();

  static String _tableLine(Order order) => order.tableId == null ? 'MANG ĐI' : 'Bàn: ${order.tableName}';

  /// Phiếu bếp cho phần vừa báo (đã tách theo máy in). [station] = tên máy in, vd "Quầy bar".
  static Ticket kitchen(KitchenSlip slip, Order order, {String? station}) {
    final lines = <TicketLine>[
      const TicketText('PHIẾU BẾP', align: TextAlign.center, scale: 1.3, bold: true),
      if (station != null) TicketText(station, align: TextAlign.center),
      const TicketDivider(),
      TicketText(_tableLine(order), scale: 1.5, bold: true),
      TicketText('Mã đơn: ${order.orderNo}'),
      TicketText('Giờ: ${formatDateTime(slip.createdAt)} — ${slip.staff ?? ''}'),
      if ((slip.orderNote ?? '').isNotEmpty) TicketText('Ghi chú: ${slip.orderNote}'),
      const TicketDivider(),
    ];

    void addLines(List<SlipLine> items, {bool showRemovedNote = false}) {
      for (final l in items) {
        lines.add(TicketText('${l.qty} x ${l.productName}', scale: 1.25));
        if ((l.note ?? '').isNotEmpty) {
          lines.add(TicketText('   » ${l.note}', scale: 1.1, italic: true));
        } else if (showRemovedNote) {
          lines.add(const TicketText('   » (bỏ ghi chú)', scale: 1.1, italic: true));
        }
      }
    }

    addLines(slip.send);
    if (slip.changed.isNotEmpty) {
      if (slip.send.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('ĐỔI GHI CHÚ', scale: 1.2, bold: true));
      addLines(slip.changed, showRemovedNote: true);
    }
    if (slip.cancel.isNotEmpty) {
      if (slip.send.isNotEmpty || slip.changed.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('HỦY MÓN', scale: 1.2, bold: true));
      for (final l in slip.cancel) {
        lines.add(TicketText('${l.qty} x ${l.productName}', scale: 1.25));
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

    return Ticket([
      if (settings.shopName.isNotEmpty) TicketText(settings.shopName, align: TextAlign.center, scale: 1.4, bold: true),
      if (settings.shopAddress.isNotEmpty) TicketText(settings.shopAddress, align: TextAlign.center),
      TicketText(paid ? 'HÓA ĐƠN BÁN HÀNG' : 'PHIẾU TẠM TÍNH', align: TextAlign.center, bold: true),
      const TicketDivider(),
      TicketText(paid ? 'Số HĐ: ${order.orderNo}' : 'Mã đơn: ${order.orderNo}'),
      TicketText(order.tableId == null ? 'Mang đi' : 'Bàn: ${order.tableName}'),
      TicketText('Thời gian: ${formatDateTime(paid ? order.paidAt : null)}'),
      if ((order.createdByName ?? '').isNotEmpty) TicketText('Nhân viên: ${order.createdByName}'),
      if (!paid && (order.note ?? '').isNotEmpty) TicketText('Ghi chú: ${order.note}'),
      const TicketDivider(),
      for (final it in items) ...[
        TicketText((it.note ?? '').isEmpty || paid ? it.productName : '${it.productName} (${it.note})'),
        TicketRow('${it.qty} x ${money(it.price)}', money(it.amount)),
      ],
      const TicketDivider(),
      TicketRow('Tạm tính', money(order.subtotal)),
      if (order.discountAmount > 0) TicketRow('Giảm giá', '-${money(order.discountAmount)}'),
      if (order.vatAmount > 0) TicketRow('VAT', money(order.vatAmount)),
      TicketRow('TỔNG CỘNG', money(order.totalAmount), scale: 1.3, bold: true),
      if (paid && payment != null) ...[
        const TicketDivider(),
        TicketRow('Hình thức TT', payment.methodLabel),
        if (payment.method == PaymentMethod.cash.code) ...[
          TicketRow('Khách đưa', money(payment.receivedAmount)),
          TicketRow('Tiền thối', money(payment.changeAmount)),
        ],
      ],
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
