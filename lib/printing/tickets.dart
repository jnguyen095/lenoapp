import 'package:flutter/painting.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'print_settings.dart';
import 'ticket.dart';
import 'vietqr.dart';

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
      const TicketDivider(),
      TicketBoxSplit(order.tableId == null ? 'Mang đi' : order.tableName, [
        'Số HĐ: ${order.orderNo}',
        'Thời gian: ${formatDateTime(slip.createdAt)}',
      ], note: (slip.orderNote ?? '').isEmpty ? null : 'Ghi chú: ${slip.orderNote}'),
      const TicketDivider(),
    ];

    // Mỗi món một hàng, kẻ đường liền giữa các món (đậm hơn dưới tiêu đề) cho bếp dễ đọc, tránh nhầm.
    void table(List<TicketColumns> rows) {
      lines
        ..add(header)
        ..add(const TicketRule(thickness: 2.5));
      for (var i = 0; i < rows.length; i++) {
        if (i > 0) lines.add(const TicketRule());
        lines.add(rows[i]);
      }
    }

    if (slip.send.isNotEmpty) {
      table([for (final l in slip.send) row(l.productName, l.qty, note: l.note)]);
    }
    if (slip.changed.isNotEmpty) {
      if (slip.send.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('ĐỔI GHI CHÚ', bold: true));
      table([
        for (final l in slip.changed) row(l.productName, l.qty, note: (l.note ?? '').isEmpty ? 'bỏ ghi chú' : l.note),
      ]);
    }
    if (slip.cancel.isNotEmpty) {
      if (slip.send.isNotEmpty || slip.changed.isNotEmpty) lines.add(const TicketDivider());
      lines.add(const TicketText('HỦY MÓN', bold: true));
      table([for (final l in slip.cancel) row(l.productName, l.qty)]);
    }
    return Ticket(lines);
  }

  /// Phiếu tạm tính (đơn đang mở) hoặc phiếu tính tiền (đơn đã thanh toán).
  /// [bankQr] bật thì phiếu tạm tính in mã VietQR (đúng số tiền, nội dung = số HĐ) dưới TỔNG CỘNG.
  static Ticket bill(OrderDetail detail, ReceiptInfo receipt, {BankQr? bankQr}) {
    final order = detail.order;
    final paid = order.status == Status.paid;
    final showQr = !paid && bankQr != null && bankQr.enabled && order.totalAmount > 0;
    final items = detail.items.where((i) => !i.isCancelled);
    final payment = detail.payment;
    String money(double v) => formatMoney(v, withUnit: false);
    // Bạn đã tiết kiệm = phần giảm theo bảng giá (món bị tăng giá không tính) + khuyến mãi trên tổng đơn — giống web.
    final saved = items.fold<double>(
            0, (s, it) => it.hasOffer && it.originalPrice! > it.price ? s + (it.originalPrice! - it.price) * it.qty : s) +
        order.discountAmount; // cộng cả khuyến mãi trên tổng đơn

    // Bảng món 4 cột: Tên món | Đ.Giá | SL | Tiền.
    const flex = [46.0, 21.0, 9.0, 24.0];
    const aligns = [TextAlign.left, TextAlign.right, TextAlign.center, TextAlign.right];

    return Ticket([
      if (receipt.shopName.isNotEmpty) TicketText(receipt.shopName, align: TextAlign.center, scale: 1.4, bold: true),
      // Địa chỉ - số điện thoại trên cùng một dòng (có cái nào in cái đó).
      if (receipt.address.isNotEmpty || receipt.phone.isNotEmpty)
        TicketText(
          [receipt.address, receipt.phone].where((s) => s.isNotEmpty).join(' - '),
          align: TextAlign.center,
        ),
      TicketText(paid ? 'PHIẾU TÍNH TIỀN' : 'PHIẾU TẠM TÍNH', align: TextAlign.center, scale: 1.2, bold: true),
      if ((order.createdByName ?? '').isNotEmpty)
        TicketText('NVBH: ${order.createdByName}', align: TextAlign.center),
      const TicketDivider(),
      // Trái (30): tên bàn trong khung bo góc — phải (60): Số HĐ + Thời gian.
      TicketBoxSplit(order.tableId == null ? 'Mang đi' : order.tableName, [
        'Số HĐ: ${order.orderNo}',
        'Thời gian: ${formatDateTime(paid ? order.paidAt : null)}',
        if ((order.priceBookName ?? '').isNotEmpty) 'Bảng giá: ${order.priceBookName}',
      ], note: !paid && (order.note ?? '').isNotEmpty ? 'Ghi chú: ${order.note}' : null),
      const TicketDivider(),
      const TicketColumns(['Tên món', 'Đ.Giá', 'SL', 'Tiền'], flex: flex, aligns: aligns, bold: true),
      for (final it in items) ...[
        TicketColumns(
          [it.productName, money(it.price), '${it.qty}', money(it.amount)],
          // Phiếu tạm tính: ghi chú món in nghiêng sau tên món (hóa đơn đã thanh toán thì không in).
          notes: [paid ? null : it.note, null, null, null],
          flex: flex,
          aligns: aligns,
        ),
        // Giá gốc gạch ngang ngay dưới giá mới.
        if (it.hasOffer)
          TicketColumns(['', money(it.originalPrice!), '', ''], flex: flex, aligns: aligns, scale: 0.85, strike: true),
      ],
      const TicketDivider(),
      TicketRow('Tạm tính', money(order.subtotal)),
      // Tên khuyến mãi trong ngoặc khi đang được giảm (giống web).
      TicketRow(
        order.discountAmount > 0 && (order.discountName ?? '').isNotEmpty ? 'Chiết khấu (${order.discountName})' : 'Chiết khấu',
        order.discountAmount > 0 ? '-${money(order.discountAmount)}' : '0',
      ),
      if (order.vatAmount > 0) TicketRow('VAT', money(order.vatAmount)),
      TicketRow('TỔNG CỘNG', money(order.totalAmount), bold: true),
      if (saved > 0) TicketRow('Bạn đã tiết kiệm', money(saved)),
      if (showQr) ...[
        const TicketSpace(0.4),
        TicketQr(buildVietQr(
          bankBin: bankQr.bin,
          accountNo: bankQr.accountNo,
          amount: order.totalAmount.round(),
          purpose: order.orderNo,
        )),
        const TicketText('Quét mã để chuyển khoản', align: TextAlign.center, bold: true),
        TicketText('${bankQr.bankName} - ${bankQr.accountNo}', align: TextAlign.center),
        if (bankQr.accountName.isNotEmpty) TicketText(bankQr.accountName, align: TextAlign.center),
      ],
      if (paid && payment != null) TicketRow('Hình thức TT', payment.methodLabel),
      const TicketDivider(),
      TicketText(
        paid ? receipt.footer : '-- Phiếu tạm tính, chưa phải hóa đơn --',
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
