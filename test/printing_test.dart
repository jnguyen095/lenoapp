import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/escpos.dart';
import 'package:leno_pos/printing/print_settings.dart';
import 'package:leno_pos/printing/printer_service.dart';
import 'package:leno_pos/printing/tickets.dart';
import 'package:leno_pos/printing/usb_printer.dart';

SlipLine line(int productId, String name, {int qty = 1}) => SlipLine(productId: productId, productName: name, qty: qty);

const _order = Order(
  id: 80, orderNo: 'ORD261007-0093D', orderType: 'DINE_IN', status: 'OPEN', note: 'Khách VIP',
  tableId: 21, tableName: 'Bàn 5', tableNote: null, createdByName: 'Lan', subtotal: 58000,
  discountAmount: 0, vatAmount: 0, totalAmount: 58000, createdAt: '2026-10-07 09:19:09', paidAt: null,
);

void main() {
  // Danh mục: 1 = Cà phê, 2 = Trà sữa, 3 = Đồ ăn vặt, 4 = Nước ép (chưa gán máy nào).
  const categoryOfProduct = {101: 1, 102: 2, 103: 3, 104: 4};
  const bar = PrinterConfig(id: 'bar', name: 'Quầy bar', host: '10.0.0.5', categoryIds: {1, 2});
  const kitchen = PrinterConfig(id: 'kitchen', name: 'Bếp', host: '10.0.0.6', categoryIds: {3}, kitchenDefault: true);
  const cashier = PrinterConfig(id: 'cashier', name: 'Thu ngân', host: '10.0.0.7', receipts: true);

  final slip = KitchenSlip(
    send: [line(101, 'Cà phê sữa', qty: 2), line(103, 'Khoai tây chiên'), line(104, 'Nước cam')],
    cancel: [line(102, 'Trà sữa trân châu')],
    changed: const [],
    orderNote: null,
    createdAt: '2026-10-07 09:30:00',
    staff: 'Lan',
  );

  group('routeKitchenSlip', () {
    test('splits lines by category, unassigned categories go to the default printer', () {
      final route = routeKitchenSlip(slip, [bar, kitchen, cashier], (id) => categoryOfProduct[id]);

      final byPrinter = {for (final (p, s) in route.jobs) p.id: s};
      expect(byPrinter.keys, unorderedEquals(['bar', 'kitchen']));
      expect(byPrinter['bar']!.send.map((l) => l.productName), ['Cà phê sữa']);
      expect(byPrinter['bar']!.cancel.map((l) => l.productName), ['Trà sữa trân châu']);
      expect(byPrinter['kitchen']!.send.map((l) => l.productName), ['Khoai tây chiên', 'Nước cam']);
      expect(route.unrouted, isEmpty);
    });

    test('a category assigned to two printers prints on both', () {
      final bar2 = bar.copyWith(name: 'Bar 2').copyWithId('bar2');
      final route = routeKitchenSlip(slip, [bar, bar2], (id) => categoryOfProduct[id]);
      expect(route.jobs.map((j) => j.$1.id), ['bar', 'bar2']);
      // Không có máy mặc định -> khoai tây (3) và nước cam (4) không có máy nhận.
      expect(route.unrouted.map((l) => l.productName), ['Khoai tây chiên', 'Nước cam']);
    });

    test('disabled printers are skipped', () {
      final route = routeKitchenSlip(slip, [bar.copyWith(enabled: false), kitchen], (id) => categoryOfProduct[id]);
      expect(route.jobs.single.$1.id, 'kitchen');
      expect(route.jobs.single.$2.send.length, 4 - 1); // cà phê + khoai + cam -> bếp mặc định
    });
  });

  test('PrintSettings survives encode/decode', () {
    final s = const PrintSettings(autoPrintReceipt: false, shopName: 'Leno').upsertPrinter(bar).upsertPrinter(kitchen);
    final back = PrintSettings.decode(s.encode());
    expect(back.autoPrintReceipt, isFalse);
    expect(back.printers.map((p) => p.name), ['Quầy bar', 'Bếp']);
    expect(back.printers.first.categoryIds, {1, 2});
    expect(back.printers.last.kitchenDefault, isTrue);
    expect(PrintSettings.decode('not json').printers, isEmpty);
  });

  test('EscPos.raster packs dark pixels MSB-first per row', () {
    // Ảnh 10×2: dòng 0 điểm 0 và 9 đen, dòng 1 trắng.
    final rgba = Uint8List(10 * 2 * 4)..fillRange(0, 10 * 2 * 4, 255);
    void black(int x, int y) => rgba.setRange((y * 10 + x) * 4, (y * 10 + x) * 4 + 3, [0, 0, 0]);
    black(0, 0);
    black(9, 0);

    final bytes = EscPos.raster(rgba, 10, 2);
    expect(bytes.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]); // 2 byte/dòng, 2 dòng
    expect(bytes.sublist(8), [0x80, 0x40, 0x00, 0x00]);
  });

  testWidgets('prints a kitchen ticket to a LAN printer over TCP', (tester) async {
    await tester.runAsync(() async {
      // Máy in giả: nhận mọi byte gửi tới cổng TCP.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = BytesBuilder();
      final done = Completer<void>();
      server.listen((client) => client.listen(received.add, onDone: done.complete));

      final printer = PrinterConfig(id: 't', name: 'Test', host: '127.0.0.1', port: server.port);
      await PrinterService().printTicket(printer, Tickets.kitchen(slip, _order, station: 'Quầy bar'));
      await done.future.timeout(const Duration(seconds: 5));
      await server.close();

      final bytes = received.toBytes();
      expect(bytes.sublist(0, 2), EscPos.initialize);
      expect(bytes.sublist(2, 8), [0x1D, 0x76, 0x30, 0x00, 576 ~/ 8, 0]); // khổ 80 mm = 72 byte/dòng
      expect(bytes.sublist(bytes.length - 4), EscPos.cutPartial);
      expect(bytes.length, greaterThan(72 * 200)); // có ảnh thật, không rỗng
    });
  });

  group('USB printer', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const usbPrinter = PrinterConfig(
      id: 'u', name: 'Quầy USB', connection: PrinterConnection.usb,
      usbVendorId: 0x0416, usbProductId: 0x5011, usbDeviceName: '/dev/bus/usb/001/002', usbLabel: 'XP-80C',
    );

    setUp(() => UsbPrinters.debugSupportedOverride = true);
    tearDown(() {
      UsbPrinters.debugSupportedOverride = null;
      messenger.setMockMethodCallHandler(UsbPrinters.channel, null);
    });

    test('sends ESC/POS bytes through the Android channel', () async {
      MethodCall? call;
      messenger.setMockMethodCallHandler(UsbPrinters.channel, (c) async {
        call = c;
        return true;
      });

      await PrinterService().sendRaw(usbPrinter, [0x1B, 0x40, 0x0A]);

      expect(call!.method, 'write');
      expect(call!.arguments['vendorId'], 0x0416);
      expect(call!.arguments['productId'], 0x5011);
      expect(call!.arguments['deviceName'], '/dev/bus/usb/001/002');
      expect(call!.arguments['bytes'], [0x1B, 0x40, 0x0A]);
    });

    test('native error becomes a Vietnamese PrintException', () async {
      messenger.setMockMethodCallHandler(UsbPrinters.channel, (c) async {
        throw PlatformException(code: 'NOT_FOUND', message: 'Không thấy máy in USB.');
      });
      expect(
        () => PrinterService().sendRaw(usbPrinter, [0x1B]),
        throwsA(isA<PrintException>().having((e) => e.message, 'message', 'Máy in "Quầy USB": Không thấy máy in USB.')),
      );
    });

    test('lists USB printers', () async {
      messenger.setMockMethodCallHandler(UsbPrinters.channel, (c) async => [
            {'vendorId': 0x0416, 'productId': 0x5011, 'deviceName': '/dev/bus/usb/001/002',
             'manufacturerName': 'Xprinter', 'productName': 'XP-80C', 'hasPermission': false},
          ]);
      final devices = await UsbPrinters.list();
      expect(devices.single.label, 'Xprinter XP-80C');
      expect(devices.single.ids, '0416:5011');
    });

    test('USB settings survive encode/decode, old LAN settings default to LAN', () {
      final back = PrintSettings.decode(const PrintSettings().upsertPrinter(usbPrinter).encode()).printers.single;
      expect(back.isUsb, isTrue);
      expect(back.usbVendorId, 0x0416);
      expect(back.address, 'USB · XP-80C');

      final old = PrinterConfig.fromJson({'id': 'a', 'name': 'Bếp', 'host': '10.0.0.6', 'port': 9100});
      expect(old.connection, PrinterConnection.lan);
      expect(old.queueKey, 'lan:10.0.0.6:9100');
    });
  });

  test('unreachable printer reports a Vietnamese error', () async {
    // Cổng 1 trên localhost luôn bị từ chối.
    const printer = PrinterConfig(id: 'x', name: 'Bếp', host: '127.0.0.1', port: 1);
    expect(
      () => PrinterService().sendRaw(printer, [0x1B, 0x40]),
      throwsA(isA<PrintException>().having((e) => e.message, 'message', contains('Không kết nối được máy in "Bếp"'))),
    );
  });
}

extension on PrinterConfig {
  PrinterConfig copyWithId(String id) => PrinterConfig(
        id: id, name: name, host: host, port: port, paper: paper, categoryIds: categoryIds,
        kitchenDefault: kitchenDefault, receipts: receipts, enabled: enabled,
      );
}
