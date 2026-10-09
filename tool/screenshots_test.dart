// Chụp màn hình các màn chính ở cỡ điện thoại / tablet dọc / tablet ngang và ảnh các phiếu in,
// dùng dữ liệu giả — để kiểm tra bố cục mà không cần máy thật. Ảnh ra build/screenshots/.
//
//   flutter test tool/screenshots_test.dart
//
// (Không nằm trong test/ nên `flutter test` thường không chạy file này.)
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leno_pos/app.dart';
import 'package:leno_pos/core/api_client.dart';
import 'package:leno_pos/customer_display/customer_display_view.dart';
import 'package:leno_pos/customer_display/display_models.dart';
import 'package:leno_pos/data/pos_repository.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/printing/print_settings.dart';
import 'package:leno_pos/printing/ticket.dart';
import 'package:leno_pos/printing/tickets.dart';
import 'package:leno_pos/printing/usb_printer.dart';
import 'package:leno_pos/printing/vietqr.dart';
import 'package:leno_pos/state/auth.dart';
import 'package:leno_pos/state/printing.dart';
import 'package:leno_pos/ui/screens/home_screen.dart';
import 'package:leno_pos/ui/screens/login_screen.dart';
import 'package:leno_pos/ui/screens/order_history_screen.dart';
import 'package:leno_pos/ui/screens/order_screen.dart';
import 'package:leno_pos/ui/screens/printer_edit_screen.dart';
import 'package:leno_pos/ui/screens/printer_settings_screen.dart';
import 'package:leno_pos/ui/screens/store_settings_screen.dart';
import 'package:leno_pos/ui/widgets/top_toast.dart';

const outDir = 'build/screenshots';

const sizes = {
  'phone': Size(390, 844),
  'tablet_portrait': Size(800, 1280),
  'tablet_landscape': Size(1280, 800),
};

/// yymmdd hôm nay — số đơn giả giống định dạng máy chủ (ORDyymmdd-xxxxx).
String _ymd() {
  final t = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.year % 100)}${two(t.month)}${two(t.day)}';
}

String _ago(int minutes) {
  final t = DateTime.now().subtract(Duration(minutes: minutes));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:00';
}

final tables = <PosTable>[
  PosTable(id: 16, code: 'MANG-DI', name: 'Mang đi', note: null, capacity: 0, isTakeaway: true, status: 'OPEN',
      order: OrderSummary(id: 54, orderNo: 'ORD1', status: 'OPEN', totalAmount: 25000, createdAt: _ago(12))),
  for (var i = 1; i <= 15; i++)
    PosTable(
      id: i,
      code: 'T${i.toString().padLeft(2, '0')}',
      name: 'Bàn $i',
      note: i == 3 ? 'Gần cửa sổ' : null,
      capacity: i <= 10 ? 4 : 6,
      isTakeaway: false,
      status: const {2: 'OPEN', 3: 'OPEN', 5: 'WAIT_PAYMENT', 8: 'OPEN', 11: 'OPEN'}[i] ?? 'AVAILABLE',
      order: const {2, 3, 5, 8, 11}.contains(i)
          ? OrderSummary(id: 80 + i, orderNo: 'ORD$i', status: 'OPEN', totalAmount: 38000.0 * i, createdAt: _ago(i * 9))
          : null,
    ),
];

final menu = <MenuCategory>[
  const MenuCategory(id: 1, name: 'Cà phê phin', products: [
    Product(id: 101, categoryId: 1, sku: 'CP-01', name: 'Cà phê đen đá', price: 15000),
    Product(id: 102, categoryId: 1, sku: 'CP-02', name: 'Cà phê sữa đá', price: 18000),
    Product(id: 103, categoryId: 1, sku: 'CP-03', name: 'Bạc xỉu', price: 22000),
    Product(id: 104, categoryId: 1, sku: 'CP-04', name: 'Cà phê muối', price: 25000),
  ]),
  const MenuCategory(id: 2, name: 'Trà sữa', products: [
    Product(id: 201, categoryId: 2, sku: 'TS-01', name: 'Trà sữa trân châu đường đen', price: 30000),
    Product(id: 202, categoryId: 2, sku: 'TS-02', name: 'Trà sữa matcha', price: 32000),
  ]),
  const MenuCategory(id: 3, name: 'Trà trái cây', products: [
    Product(id: 301, categoryId: 3, sku: 'TT-01', name: 'Trà đào cam sả', price: 28000),
    Product(id: 302, categoryId: 3, sku: 'TT-02', name: 'Trà vải', price: 28000),
  ]),
  const MenuCategory(id: 4, name: 'Đồ ăn vặt', products: [
    Product(id: 401, categoryId: 4, sku: 'DA-01', name: 'Khoai tây chiên', price: 25000),
    Product(id: 402, categoryId: 4, sku: 'DA-02', name: 'Bánh mì ốp la', price: 20000),
    Product(id: 403, categoryId: 4, sku: 'DA-03', name: 'Hướng dương', price: 10000),
  ]),
];

OrderItem item(int id, int productId, String name, int qty, double price,
        {int notified = 0, String? note, String status = 'ACTIVE', bool? pending}) =>
    OrderItem(
      id: id, productId: productId, productName: name, image: null, qty: qty, notifiedQty: notified,
      price: price, amount: price * qty, note: note, notifiedNote: notified > 0 ? note : null, status: status,
      pending: pending ?? (qty != notified),
    );

OrderDetail order({bool paid = false}) {
  final items = [
    item(1, 102, 'Cà phê sữa đá', 2, 18000, notified: 2, note: 'Ít đá'),
    item(2, 201, 'Trà sữa trân châu đường đen', 1, 30000, notified: 1),
    item(3, 401, 'Khoai tây chiên', 1, 25000),
    item(4, 301, 'Trà đào cam sả', 3, 28000, note: 'Không đường'),
  ];
  final total = items.fold<double>(0, (s, i) => s + i.amount);
  return OrderDetail(
    order: Order(
      id: 83, orderNo: 'ORD${_ymd()}-0192B', orderType: 'DINE_IN', status: paid ? 'PAID' : 'OPEN', note: 'Khách VIP',
      tableId: 3, tableName: 'Bàn 3', tableNote: 'Gần cửa sổ', createdByName: 'Nguyễn Thị Lan', subtotal: total,
      discountAmount: 0, vatAmount: 0, totalAmount: total, createdAt: _ago(27), paidAt: paid ? _ago(0) : null,
    ),
    isActive: !paid,
    items: items,
    pendingCount: paid ? 0 : 2,
    payment: paid
        ? const Payment(id: 1, method: 'CASH', methodLabel: 'Tiền mặt', amount: 175000, receivedAmount: 200000,
            changeAmount: 25000, paidAt: null)
        : null,
  );
}

class FakeRepo extends PosRepository {
  FakeRepo() : super(ApiClient(serverUrl: 'http://localhost/leno'));

  @override
  Future<List<PosTable>> tables() async => tables_;
  @override
  Future<List<MenuCategory>> menu() async => menu_;
  @override
  Future<OrderDetail> order(int orderId) async => order_();
  @override
  Future<OrderHistory> orderHistory({String? date}) async => OrderHistory(
        date: '2026-10-07',
        paidCount: 2,
        paidTotal: 213000,
        openCount: 2,
        openTotal: 289000,
        byMethod: const [
          MethodTotal(method: 'CASH', label: 'Tiền mặt', count: 1, total: 175000),
          MethodTotal(method: 'CARD', label: 'Thẻ', count: 0, total: 0),
          MethodTotal(method: 'TRANSFER', label: 'Chuyển khoản', count: 1, total: 38000),
          MethodTotal(method: 'QR', label: 'QR Pay', count: 0, total: 0),
        ],
        orders: [
          HistoryOrder(id: 83, orderNo: 'ORD${_ymd()}-0192B', status: 'OPEN', tableName: 'Bàn 3', totalAmount: 175000, itemCount: 7, createdAt: _ago(27)),
          HistoryOrder(id: 82, orderNo: 'ORD${_ymd()}-A11F2', status: 'PAID', tableName: 'Mang đi', totalAmount: 38000, itemCount: 2, methodLabel: 'Chuyển khoản', createdAt: _ago(60), paidAt: _ago(55)),
          HistoryOrder(id: 81, orderNo: 'ORD${_ymd()}-77C01', status: 'OPEN', tableName: 'Bàn 8', totalAmount: 114000, itemCount: 5, createdAt: _ago(80)),
          HistoryOrder(id: 80, orderNo: 'ORD${_ymd()}-0093D', status: 'PAID', tableName: 'Bàn 5', totalAmount: 175000, itemCount: 6, methodLabel: 'Tiền mặt', createdAt: _ago(140), paidAt: _ago(95)),
        ],
      );

  @override
  Future<List<KitchenSlip>> kitchenHistory(int orderId) async => [
        KitchenSlip(
          send: const [SlipLine(productId: 401, productName: 'Khoai tây chiên', qty: 1)],
          cancel: const [SlipLine(productId: 201, productName: 'Trà sữa trân châu đường đen', qty: 1)],
          changed: const [],
          orderNote: null,
          createdAt: _ago(3),
          staff: 'Nguyễn Thị Lan',
        ),
        KitchenSlip(
          send: const [
            SlipLine(productId: 102, productName: 'Cà phê sữa đá', qty: 2, note: 'Ít đá'),
            SlipLine(productId: 201, productName: 'Trà sữa trân châu đường đen', qty: 1),
          ],
          cancel: const [],
          changed: const [],
          orderNote: null,
          createdAt: _ago(25),
          staff: 'Khang',
        ),
      ];
}

final tables_ = tables;
final menu_ = menu;
OrderDetail order_() => order();

class FakeAuth extends AuthController {
  @override
  Future<Session?> build() async => const Session(
        serverUrl: 'http://localhost/leno',
        token: 't',
        user: User(id: 1, username: 'lan', fullname: 'Nguyễn Thị Lan', role: 'CASHIER', roleLabel: 'Thu ngân',
            canTables: true, canOrders: true),
        settings: ShopSettings(siteName: 'Leno', vatPercent: 0, takeawayEnabled: true),
      );
}

const bankQr = BankQr(enabled: true, bin: '970415', bankName: 'VietinBank', accountNo: '101874640883');

final printSettings = const PrintSettings(shopPhone: '0974 749 277')
    .upsertPrinter(const PrinterConfig(id: 'bar', name: 'Quầy bar', host: '192.168.1.101', categoryIds: {1, 2, 3}))
    .upsertPrinter(const PrinterConfig(id: 'bep', name: 'Bếp', host: '192.168.1.102', categoryIds: {4}, kitchenDefault: true))
    .upsertPrinter(const PrinterConfig(id: 'tn', name: 'Thu ngân', host: '192.168.1.100', paper: PaperWidth.mm80, receipts: true))
    .upsertPrinter(const PrinterConfig(id: 'usb', name: 'Máy in USB quầy', connection: PrinterConnection.usb,
        usbVendorId: 0x0416, usbProductId: 0x5011, usbLabel: 'Xprinter XP-80C', receipts: true));

class FakePrintSettings extends PrintSettingsController {
  @override
  Future<PrintSettings> build() async => printSettings;
}

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? (throw StateError('Set FLUTTER_ROOT to the Flutter SDK path'));
  final dir = '$root/bin/cache/artifacts/material_fonts';
  ByteData read(String f) => ByteData.view(File('$dir/$f').readAsBytesSync().buffer);

  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-italic.ttf', 'roboto-bolditalic.ttf']) {
    roboto.addFont(Future.value(read(f)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('materialicons-regular.otf')))).load();
}

final _root = GlobalKey();

Widget app(Widget home) => ProviderScope(
      overrides: [
        authProvider.overrideWith(FakeAuth.new),
        apiClientProvider.overrideWithValue(ApiClient(serverUrl: 'http://localhost/leno')),
        posRepositoryProvider.overrideWithValue(FakeRepo()),
        printSettingsProvider.overrideWith(FakePrintSettings.new),
      ],
      child: RepaintBoundary(
        key: _root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, fontFamily: 'Roboto'),
          home: home,
        ),
      ),
    );

Future<void> savePng(WidgetTester tester, ui.Image image, String name) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> shoot(WidgetTester tester, String name, Size size, Widget home, {Future<void> Function()? interact}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  debugDisableShadows = false; // chế độ test vẽ bóng thành viền đen — tắt để ảnh giống máy thật
  await tester.pumpWidget(app(home));
  await tester.pumpAndSettle();
  if (interact != null) {
    await interact();
    await tester.pumpAndSettle();
  }
  final boundary = _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async => savePng(tester, await boundary.toImage(), name));
  // Gỡ cây để huỷ bộ hẹn giờ làm mới sơ đồ bàn.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  debugDisableShadows = true;
}

void main() {
  setUpAll(loadFonts);
  customerDisplayShots();
  tearDown(() {});

  for (final e in sizes.entries) {
    testWidgets('home ${e.key}', (tester) async {
      await shoot(tester, 'home_${e.key}', e.value, const HomeScreen());
      addTearDown(tester.view.reset);
    });
    testWidgets('order ${e.key}', (tester) async {
      await shoot(tester, 'order_${e.key}', e.value, const OrderScreen(orderId: 83));
      addTearDown(tester.view.reset);
    });
  }

  testWidgets('order phone - ordered tab', (tester) async {
    await shoot(tester, 'order_phone_items', sizes['phone']!, const OrderScreen(orderId: 83),
        interact: () => tester.tap(find.textContaining('Món đã gọi')));
    addTearDown(tester.view.reset);
  });

  testWidgets('kitchen toast + history', (tester) async {
    await shoot(tester, 'order_toast_tablet_landscape', sizes['tablet_landscape']!, const OrderScreen(orderId: 83),
        interact: () async => showTopToast(tester.element(find.byType(OrderScreen)), 'Đã báo bếp: 1 món mới, 1 món hủy · đã in 2 phiếu',
            actionLabel: 'Lịch sử', onTap: () {}));
    await shoot(tester, 'kitchen_history_tablet_landscape', sizes['tablet_landscape']!, const OrderScreen(orderId: 83),
        interact: () => tester.tap(find.byIcon(Icons.history)));
    await shoot(tester, 'order_phone_items_pending', sizes['phone']!, const OrderScreen(orderId: 83),
        interact: () => tester.tap(find.textContaining('Món đã gọi')));
    addTearDown(tester.view.reset);
  });

  testWidgets('menu drawer + store settings', (tester) async {
    await shoot(tester, 'drawer_home_tablet_landscape', sizes['tablet_landscape']!, const HomeScreen(),
        interact: () => tester.tap(find.byIcon(Icons.menu)));
    await shoot(tester, 'drawer_order_phone', sizes['phone']!, const OrderScreen(orderId: 83),
        interact: () => tester.tap(find.byIcon(Icons.menu)));
    await shoot(tester, 'store_settings_tablet_portrait', sizes['tablet_portrait']!, const StoreSettingsScreen());
    addTearDown(tester.view.reset);
  });

  testWidgets('menu search', (tester) async {
    Future<void> search() async {
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'tra');
    }

    await shoot(tester, 'search_tablet_landscape', sizes['tablet_landscape']!, const OrderScreen(orderId: 83), interact: search);
    await shoot(tester, 'search_phone', sizes['phone']!, const OrderScreen(orderId: 83), interact: search);
    addTearDown(tester.view.reset);
  });

  testWidgets('order history', (tester) async {
    await shoot(tester, 'history_tablet_landscape', sizes['tablet_landscape']!, const OrderHistoryScreen());
    await shoot(tester, 'history_phone', sizes['phone']!, const OrderHistoryScreen());
    await shoot(tester, 'drawer_history_phone', sizes['phone']!, const OrderHistoryScreen(),
        interact: () => tester.tap(find.byIcon(Icons.menu)));
    addTearDown(tester.view.reset);
  });

  testWidgets('login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Future<void> loadLogo() async {
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/leno-logo.jpg'), tester.element(find.byType(LoginScreen))));
      await tester.pump();
    }

    await shoot(tester, 'login_tablet_landscape', sizes['tablet_landscape']!, const LoginScreen(), interact: loadLogo);
    await shoot(tester, 'login_phone', sizes['phone']!, const LoginScreen(), interact: loadLogo);
    addTearDown(tester.view.reset);
  });

  testWidgets('printer settings', (tester) async {
    await shoot(tester, 'printers_tablet_landscape', sizes['tablet_landscape']!, const PrinterSettingsScreen());
    await shoot(tester, 'printers_phone', sizes['phone']!, const PrinterSettingsScreen());
    await shoot(tester, 'printer_edit_tablet_portrait', sizes['tablet_portrait']!,
        PrinterEditScreen(printer: printSettings.printers.first));
    UsbPrinters.debugSupportedOverride = true;
    await shoot(tester, 'printer_edit_usb_tablet_portrait', sizes['tablet_portrait']!,
        PrinterEditScreen(printer: printSettings.printers.last));
    UsbPrinters.debugSupportedOverride = null;
    addTearDown(tester.view.reset);
  });

  testWidgets('tickets', (tester) async {
    final o = order().order;
    final slip = KitchenSlip(
      send: const [
        SlipLine(productId: 102, productName: 'Cà phê sữa đá', qty: 2, note: 'Ít đá'),
        SlipLine(productId: 301, productName: 'Trà đào cam sả', qty: 3, note: 'Không đường'),
      ],
      cancel: const [SlipLine(productId: 201, productName: 'Trà sữa trân châu đường đen', qty: 1)],
      changed: const [SlipLine(productId: 103, productName: 'Bạc xỉu', qty: 1, note: 'Nhiều sữa', oldNote: 'Ít sữa')],
      orderNote: 'Khách VIP',
      createdAt: _ago(0),
      staff: 'Nguyễn Thị Lan',
    );
    final tickets = <String, (Ticket, int)>{
      'ticket_kitchen_80mm': (Tickets.kitchen(slip, o, station: 'Quầy bar'), 576),
      'ticket_provisional_80mm': (Tickets.bill(order(), printSettings, bankQr: bankQr), 576),
      'ticket_provisional_58mm': (Tickets.bill(order(), printSettings, bankQr: bankQr), 384),
      'ticket_receipt_80mm': (Tickets.bill(order(paid: true), printSettings), 576),
      'ticket_receipt_58mm': (Tickets.bill(order(paid: true), printSettings), 384),
      'ticket_test_80mm': (Tickets.test(printSettings.printers.first, categoryNames: {for (final c in menu) c.id: c.name}), 576),
    };
    await tester.runAsync(() async {
      for (final t in tickets.entries) {
        final image = await TicketRenderer(widthDots: t.value.$2).renderImage(t.value.$1);
        await savePng(tester, image, t.key);
      }
    });
  });
}

// ---- Màn hình khách (màn hình phụ) ----
void customerDisplayShots() {
  final slideFile = File('assets/images/leno-logo.jpg').absolute.path;
  final content = DisplayContent(
    shopName: 'Leno Quán',
    config: const DisplayConfig(welcomeText: 'Chào mừng quý khách đến với Leno', thanksText: 'Cảm ơn quý khách - Hẹn gặp lại!'),
    slides: [DisplaySlide(id: 1, url: 'assets/x.jpg', file: slideFile)],
    version: 'v1',
  );
  const lines = [
    DisplayLine(name: 'Cà phê sữa đá', qty: 2, price: 18000, amount: 36000),
    DisplayLine(name: 'Trà sữa trân châu đường đen', qty: 1, price: 30000, amount: 30000),
    DisplayLine(name: 'Khoai tây chiên', qty: 1, price: 25000, amount: 25000),
    DisplayLine(name: 'Trà đào cam sả', qty: 3, price: 28000, amount: 84000),
  ];
  final states = <String, (DisplayContent, DisplaySnapshot)>{
    'idle_noslides': (content.copyWith(slides: const []), const DisplaySnapshot.idle()),
    'order': (content, const DisplaySnapshot(state: DisplayState.order, orderId: 1, tableName: 'Bàn 3', lines: lines, subtotal: 175000, total: 175000)),
    'paying': (
      content,
      DisplaySnapshot(
        state: DisplayState.paying, orderId: 1, tableName: 'Bàn 3', lines: lines, subtotal: 175000, total: 175000,
        orderNo: 'ORD${_ymd()}-0192B', bankName: 'VietinBank', accountNo: '101874640883', accountName: 'NGUYỄN NHƯ KHANG',
        qrPayload: buildVietQr(bankBin: '970415', accountNo: '101874640883', amount: 175000, purpose: 'ORD${_ymd()}-0192B'),
      )
    ),
    'thanks': (content, const DisplaySnapshot(state: DisplayState.thanks, orderId: 1, total: 175000, methodLabel: 'Tiền mặt', received: 200000, change: 25000)),
    'idle_slides': (content, const DisplaySnapshot.idle()),
  };
  const displaySizes = {'1280x800': Size(1280, 800), '1024x600': Size(1024, 600), 'portrait': Size(800, 1280)};

  for (final size in displaySizes.entries) {
    testWidgets('customer display ${size.key}', (tester) async {
      for (final s in states.entries) {
        await shoot(tester, 'cd_${s.key}_${size.key}', size.value,
            Scaffold(body: CustomerDisplayView(content: s.value.$1, snapshot: s.value.$2)),
            interact: () async {
          await tester.runAsync(() async {
            final ctx = tester.element(find.byType(CustomerDisplayView));
            await precacheImage(FileImage(File(slideFile)), ctx);
            await precacheImage(const AssetImage('assets/images/leno-logo.jpg'), ctx);
          });
          await tester.pump();
        });
      }
      addTearDown(tester.view.reset);
    });
  }
}
