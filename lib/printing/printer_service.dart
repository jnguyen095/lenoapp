import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'escpos.dart';
import 'print_settings.dart';
import 'ticket.dart';
import 'usb_printer.dart';

class PrintException implements Exception {
  PrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Gửi phiếu tới máy in: LAN qua TCP (cổng 9100, chuẩn "RAW/JetDirect") hoặc USB (Android).
/// Mỗi máy in một hàng đợi: phiếu gửi lần lượt, không chen nhau.
class PrinterService {
  static const connectTimeout = Duration(seconds: 5);

  final _queues = <String, Future<void>>{};

  Future<void> printTicket(PrinterConfig printer, Ticket ticket, {int copies = 1}) async {
    final image = await TicketRenderer(widthDots: printer.paper.dots).renderRgba(ticket);
    final raster = EscPos.raster(image.rgba, image.width, image.height);
    await sendRaw(printer, EscPos.job(raster, copies: copies));
  }

  Future<void> sendRaw(PrinterConfig printer, List<int> bytes) {
    final key = printer.queueKey;
    final previous = _queues[key] ?? Future<void>.value();
    final next = previous.then((_) => printer.isUsb ? _sendUsb(printer, bytes) : _sendLan(printer, bytes));
    _queues[key] = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _sendUsb(PrinterConfig printer, List<int> bytes) async {
    if (!UsbPrinters.supported) {
      throw PrintException('Máy in USB "${printer.name}" chỉ dùng được trên máy Android.');
    }
    if (printer.usbVendorId == null || printer.usbProductId == null) {
      throw PrintException('Máy in "${printer.name}" chưa chọn thiết bị USB.');
    }
    try {
      await UsbPrinters.write(printer.usbVendorId!, printer.usbProductId!, bytes, deviceName: printer.usbDeviceName)
          .timeout(const Duration(seconds: 60));
    } on PlatformException catch (e) {
      throw PrintException('Máy in "${printer.name}": ${e.message ?? e.code}');
    } on TimeoutException {
      throw PrintException('Máy in USB "${printer.name}" không phản hồi.');
    }
  }

  Future<void> _sendLan(PrinterConfig printer, List<int> bytes) async {
    Socket socket;
    try {
      socket = await Socket.connect(printer.host, printer.port, timeout: connectTimeout);
    } on SocketException {
      throw PrintException('Không kết nối được máy in "${printer.name}" (${printer.address}). '
          'Kiểm tra máy in đã bật, cắm dây mạng và đúng địa chỉ IP.');
    }
    try {
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 20));
    } on Object {
      throw PrintException('Gửi phiếu tới máy in "${printer.name}" bị gián đoạn.');
    } finally {
      await socket.close().timeout(const Duration(seconds: 5), onTimeout: () => socket.destroy());
    }
  }

  /// Dò máy in trong mạng LAN: thử mở cổng [port] ở mọi địa chỉ cùng dải /24 với máy này.
  static Future<List<String>> discover({int port = 9100}) async {
    final prefixes = <String>{};
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback || addr.isLinkLocal) continue;
        final parts = addr.address.split('.');
        if (parts.length == 4) prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }

    final found = <String>[];
    Future<void> probe(String host) async {
      try {
        final s = await Socket.connect(host, port, timeout: const Duration(milliseconds: 400));
        s.destroy();
        found.add(host);
      } catch (_) {}
    }

    for (final prefix in prefixes) {
      // Thử 64 địa chỉ một lượt để không mở quá nhiều kết nối cùng lúc.
      for (var start = 1; start < 255; start += 64) {
        await Future.wait([
          for (var i = start; i < start + 64 && i < 255; i++) probe('$prefix.$i'),
        ]);
      }
    }
    found.sort((a, b) => int.parse(a.split('.').last).compareTo(int.parse(b.split('.').last)));
    return found;
  }
}
