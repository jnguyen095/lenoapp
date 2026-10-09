import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/customer_display/customer_display_controller.dart';
import 'package:leno_pos/customer_display/display_bridge.dart';
import 'package:leno_pos/customer_display/display_models.dart';
import 'package:leno_pos/customer_display/slide_cache.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/print_settings.dart';
import 'package:leno_pos/state/auth.dart';
import 'package:leno_pos/state/printing.dart';

/// Ghi lại những gì ứng dụng gửi sang màn hình phụ.
class _FakeBridge extends DisplayBridge {
  final snapshots = <DisplaySnapshot>[];
  final contents = <DisplayContent>[];

  @override
  Future<void> sendSnapshot(DisplaySnapshot snapshot) async => snapshots.add(snapshot);

  @override
  Future<void> sendContent(DisplayContent content) async => contents.add(content);
}

class _FakeAuth extends AuthController {
  _FakeAuth({this.bank});

  final BankQr? bank;

  @override
  Future<Session?> build() async => Session(
        serverUrl: 'http://localhost/leno',
        token: 't',
        user: const User(id: 1, username: 'lan', fullname: 'Lan', role: 'CASHIER', roleLabel: 'Thu ngân',
            canTables: true, canOrders: true),
        settings: ShopSettings(siteName: 'Leno', vatPercent: 0, takeawayEnabled: true, bankQr: bank),
      );
}

class _FakePrintSettings extends PrintSettingsController {
  @override
  Future<PrintSettings> build() async => const PrintSettings(shopName: 'Leno Quán');
}

OrderDetail _order({int id = 7, String status = 'OPEN', Payment? payment}) {
  OrderItem item(int itemId, String name, int qty, double price, {String? note, String st = 'ACTIVE'}) => OrderItem(
        id: itemId, productId: itemId, productName: name, image: null, qty: qty, notifiedQty: 0, price: price,
        amount: price * qty, note: note, notifiedNote: null, status: st, pending: true,
      );
  return OrderDetail(
    order: Order(
      id: id, orderNo: 'ORD261008-0001A', orderType: 'DINE_IN', status: status, note: null, tableId: 3,
      tableName: 'Bàn 3', tableNote: null, createdByName: 'Lan', subtotal: 64000, discountAmount: 0, vatAmount: 0,
      totalAmount: 64000, createdAt: null, paidAt: null,
    ),
    isActive: status == 'OPEN',
    items: [
      item(1, 'Cà phê sữa đá', 2, 18000, note: 'Ít đá'),
      item(2, 'Trà đào', 1, 28000),
      item(3, 'Món đã hủy', 1, 99000, st: 'CANCELLED'),
    ],
    pendingCount: 2,
    payment: payment,
  );
}

const _bank = BankQr(enabled: true, bin: '970415', bankName: 'VietinBank', accountNo: '101874640883', accountName: 'NGUYEN VAN A');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBridge bridge;
  late ProviderContainer container;

  Future<CustomerDisplayController> setUpController({BankQr? bank = _bank, DisplayConfig? config}) async {
    bridge = _FakeBridge();
    container = ProviderContainer(overrides: [
      displayBridgeProvider.overrideWithValue(bridge),
      authProvider.overrideWith(() => _FakeAuth(bank: bank)),
      printSettingsProvider.overrideWith(_FakePrintSettings.new),
    ]);
    await container.read(authProvider.future);
    final c = container.read(customerDisplayProvider.notifier);
    if (config != null) {
      // Giả lập nội dung đã tải từ máy chủ.
      c.debugSetContent(DisplayContent(config: config));
    }
    return c;
  }

  tearDown(() => container.dispose());

  test('order snapshot: active items only, notes hidden by default', () async {
    final c = await setUpController();
    c.showOrder(_order());
    final s = bridge.snapshots.last;
    expect(s.state, DisplayState.order);
    expect(s.tableName, 'Bàn 3');
    expect(s.lines.map((l) => l.name), ['Cà phê sữa đá', 'Trà đào']);
    expect(s.lines.first.note, isNull);
    expect(s.itemCount, 3);
    expect(s.total, 64000);
  });

  test('order snapshot shows notes when enabled on web', () async {
    final c = await setUpController(config: const DisplayConfig(showItemNotes: true));
    c.showOrder(_order());
    expect(bridge.snapshots.last.lines.first.note, 'Ít đá');
  });

  test('transfer shows VietQR with exact amount and order number; cash shows the order', () async {
    final c = await setUpController();
    c.startPaying(_order(), PaymentMethod.cash);
    expect(bridge.snapshots.last.state, DisplayState.order);

    c.startPaying(_order(), PaymentMethod.transfer);
    final s = bridge.snapshots.last;
    expect(s.state, DisplayState.paying);
    expect(s.qrPayload, contains('0112101874640883')); // tài khoản
    expect(s.qrPayload, contains('540564000')); // số tiền 64.000
    expect(s.qrPayload, contains('ORD261008-0001A')); // nội dung = số HĐ
    expect(s.accountName, 'NGUYEN VAN A');

    c.cancelPaying(7);
    expect(bridge.snapshots.last.state, DisplayState.order);
  });

  test('no QR when bank QR is off or disabled on the display settings', () async {
    var c = await setUpController(bank: const BankQr(enabled: false, bin: '970415', bankName: 'VietinBank', accountNo: '1'));
    c.startPaying(_order(), PaymentMethod.transfer);
    expect(bridge.snapshots.last.state, DisplayState.order);
    container.dispose();

    c = await setUpController(config: const DisplayConfig(showQr: false));
    c.startPaying(_order(), PaymentMethod.qr);
    expect(bridge.snapshots.last.state, DisplayState.order);
  });

  testWidgets('thanks -> idle timer, and leaving the order does not cut the thanks short', (tester) async {
    final c = await setUpController(config: const DisplayConfig(thanksSeconds: 3));
    c.showOrder(_order());
    const pay = Payment(id: 1, method: 'CASH', methodLabel: 'Tiền mặt', amount: 64000, receivedAmount: 100000,
        changeAmount: 36000, paidAt: null);
    c.showThanks(_order(status: 'PAID', payment: pay));
    expect(bridge.snapshots.last.state, DisplayState.thanks);
    expect(bridge.snapshots.last.change, 36000);

    c.leaveOrder(7); // màn hình đơn đóng sau khi thanh toán
    expect(bridge.snapshots.last.state, DisplayState.thanks);

    await tester.pump(const Duration(seconds: 2));
    expect(bridge.snapshots.last.state, DisplayState.thanks);
    await tester.pump(const Duration(seconds: 2));
    expect(bridge.snapshots.last.state, DisplayState.idle);
  });

  test('leaving the order screen returns to idle', () async {
    final c = await setUpController();
    c.showOrder(_order());
    c.leaveOrder(99); // đơn khác -> không đổi
    expect(bridge.snapshots.last.state, DisplayState.order);
    c.leaveOrder(7);
    expect(bridge.snapshots.last.state, DisplayState.idle);
  });

  test('closed (paid) orders are not shown as an order', () async {
    final c = await setUpController();
    c.showOrder(_order(status: 'PAID'));
    expect(bridge.snapshots, isEmpty);
  });

  test('snapshot and content survive JSON round trip', () {
    const s = DisplaySnapshot(
      state: DisplayState.paying, orderId: 5, tableName: 'Bàn 5',
      lines: [DisplayLine(name: 'A', qty: 2, price: 10, amount: 20, note: 'n')],
      subtotal: 20, discount: 0, total: 20, qrPayload: 'QR', bankName: 'B', accountNo: '1', orderNo: 'O',
    );
    final back = DisplaySnapshot.fromJson(s.toJson());
    expect(back.state, DisplayState.paying);
    expect(back.lines.single.note, 'n');
    expect(back.qrPayload, 'QR');

    const content = DisplayContent(
      shopName: 'Leno',
      config: DisplayConfig(slideSeconds: 12, textScale: 1.2),
      slides: [DisplaySlide(id: 1, url: 'assets/uploads/display/a.jpg', file: '/x/a.jpg', durationSeconds: 5)],
      version: 'v1',
    );
    final c2 = DisplayContent.fromJson(content.toJson());
    expect(c2.config.slideSeconds, 12);
    expect(c2.readySlides.single.durationSeconds, 5);
  });

  test('SlideCache downloads new images, keeps cached ones, skips failures, cleans old files', () async {
    final tmp = await Directory.systemTemp.createTemp('slides');
    addTearDown(() => tmp.delete(recursive: true));
    final cache = SlideCache(baseDir: () async => tmp);
    var downloads = 0;
    Future<List<int>> download(String url) async {
      downloads++;
      if (url.contains('broken')) throw Exception('404');
      return [1, 2, 3];
    }

    const a = DisplaySlide(id: 1, url: 'assets/uploads/display/a.jpg', updatedAt: '2026-10-08 10:00:00');
    const broken = DisplaySlide(id: 2, url: 'assets/uploads/display/broken.png', updatedAt: 'x');
    var out = await cache.sync([a, broken], download);
    expect(out.first.file, isNotNull);
    expect(File(out.first.file!).readAsBytesSync(), [1, 2, 3]);
    expect(out.last.file, isNull); // tải lỗi -> bỏ qua ảnh này
    expect(downloads, 2);

    out = await cache.sync([a], download); // đã có -> không tải lại
    expect(downloads, 2);

    // Ảnh sửa trên web (updated_at đổi) -> tải bản mới, xoá bản cũ.
    const a2 = DisplaySlide(id: 1, url: 'assets/uploads/display/a.jpg', updatedAt: '2026-10-09 09:00:00');
    out = await cache.sync([a2], download);
    expect(downloads, 3);
    final files = Directory('${tmp.path}${Platform.pathSeparator}display_slides').listSync();
    expect(files.length, 1);
  });
}
