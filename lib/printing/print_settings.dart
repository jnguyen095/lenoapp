import 'dart:convert';

/// Khổ giấy máy in nhiệt — số điểm in trên một dòng.
enum PaperWidth {
  mm80(576, '80 mm'),
  mm80Narrow(512, '80 mm (512 điểm)'),
  mm58(384, '58 mm');

  const PaperWidth(this.dots, this.label);

  final int dots;
  final String label;

  static PaperWidth byName(String? name) =>
      PaperWidth.values.firstWhere((p) => p.name == name, orElse: () => PaperWidth.mm80);
}

/// Cách nối máy in.
enum PrinterConnection {
  lan('Mạng LAN'),
  usb('USB');

  const PrinterConnection(this.label);

  final String label;

  static PrinterConnection byName(String? name) =>
      PrinterConnection.values.firstWhere((c) => c.name == name, orElse: () => PrinterConnection.lan);
}

/// Một máy in nhiệt: nối mạng LAN (ESC/POS qua TCP, thường cổng 9100) hoặc cắm USB vào máy POS Android.
class PrinterConfig {
  const PrinterConfig({
    required this.id,
    required this.name,
    this.connection = PrinterConnection.lan,
    this.host = '',
    this.port = 9100,
    this.usbVendorId,
    this.usbProductId,
    this.usbDeviceName,
    this.usbLabel,
    this.paper = PaperWidth.mm80,
    this.categoryIds = const {},
    this.kitchenDefault = false,
    this.receipts = false,
    this.enabled = true,
  });

  factory PrinterConfig.fromJson(Map<String, dynamic> j) => PrinterConfig(
        id: j['id'] as String,
        name: j['name'] as String,
        connection: PrinterConnection.byName(j['connection'] as String?),
        host: (j['host'] as String?) ?? '',
        port: (j['port'] as num?)?.toInt() ?? 9100,
        usbVendorId: (j['usb_vendor_id'] as num?)?.toInt(),
        usbProductId: (j['usb_product_id'] as num?)?.toInt(),
        usbDeviceName: j['usb_device_name'] as String?,
        usbLabel: j['usb_label'] as String?,
        paper: PaperWidth.byName(j['paper'] as String?),
        categoryIds: ((j['category_ids'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        kitchenDefault: j['kitchen_default'] == true,
        receipts: j['receipts'] == true,
        enabled: j['enabled'] != false,
      );

  final String id;
  final String name;
  final PrinterConnection connection;

  // Mạng LAN
  final String host;
  final int port;

  // USB: nhận máy in theo vendorId/productId (deviceName chỉ để phân biệt khi có 2 máy giống hệt nhau).
  final int? usbVendorId;
  final int? usbProductId;
  final String? usbDeviceName;
  final String? usbLabel;

  final PaperWidth paper;

  /// Danh mục thực đơn in phiếu bếp ra máy này (vd: Cà phê, Trà sữa -> máy quầy bar).
  final Set<int> categoryIds;

  /// Nhận phiếu bếp của các danh mục chưa gán máy in nào.
  final bool kitchenDefault;

  /// In phiếu tạm tính và hóa đơn thanh toán.
  final bool receipts;

  final bool enabled;

  bool get isUsb => connection == PrinterConnection.usb;

  /// Mô tả nơi nối máy in, vd "192.168.1.100" hoặc "USB · XP-80C".
  String get address => isUsb
      ? 'USB · ${usbLabel ?? 'chưa chọn máy'}'
      : (port == 9100 ? host : '$host:$port');

  /// Khóa hàng đợi in: cùng một máy in thì gửi lần lượt.
  String get queueKey => isUsb ? 'usb:$usbVendorId:$usbProductId' : 'lan:$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connection': connection.name,
        'host': host,
        'port': port,
        'usb_vendor_id': usbVendorId,
        'usb_product_id': usbProductId,
        'usb_device_name': usbDeviceName,
        'usb_label': usbLabel,
        'paper': paper.name,
        'category_ids': categoryIds.toList()..sort(),
        'kitchen_default': kitchenDefault,
        'receipts': receipts,
        'enabled': enabled,
      };

  PrinterConfig copyWith({
    String? name,
    String? host,
    int? port,
    PaperWidth? paper,
    Set<int>? categoryIds,
    bool? kitchenDefault,
    bool? receipts,
    bool? enabled,
  }) =>
      PrinterConfig(
        id: id,
        name: name ?? this.name,
        connection: connection,
        host: host ?? this.host,
        port: port ?? this.port,
        usbVendorId: usbVendorId,
        usbProductId: usbProductId,
        usbDeviceName: usbDeviceName,
        usbLabel: usbLabel,
        paper: paper ?? this.paper,
        categoryIds: categoryIds ?? this.categoryIds,
        kitchenDefault: kitchenDefault ?? this.kitchenDefault,
        receipts: receipts ?? this.receipts,
        enabled: enabled ?? this.enabled,
      );
}

/// Cấu hình in của máy (tablet) này — lưu trên máy, mỗi máy tự cài.
class PrintSettings {
  const PrintSettings({
    this.printers = const [],
    this.autoPrintKitchen = true,
    this.autoPrintReceipt = true,
    this.shopName = 'Leno',
    this.shopAddress = '28 Võ Văn Kiệt, BMT',
    this.footer = 'Cảm ơn quý khách - Hẹn gặp lại!',
  });

  factory PrintSettings.fromJson(Map<String, dynamic> j) => PrintSettings(
        printers: ((j['printers'] as List?) ?? const [])
            .map((p) => PrinterConfig.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
        autoPrintKitchen: j['auto_print_kitchen'] != false,
        autoPrintReceipt: j['auto_print_receipt'] != false,
        shopName: (j['shop_name'] as String?) ?? 'Leno',
        shopAddress: (j['shop_address'] as String?) ?? '',
        footer: (j['footer'] as String?) ?? '',
      );

  factory PrintSettings.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const PrintSettings();
    try {
      return PrintSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PrintSettings();
    }
  }

  final List<PrinterConfig> printers;

  /// Tự in phiếu bếp mỗi lần bấm "Báo bếp".
  final bool autoPrintKitchen;

  /// Tự in hóa đơn ngay sau khi thanh toán.
  final bool autoPrintReceipt;

  /// Dòng đầu hóa đơn / phiếu tạm tính (web đang in "Leno" + địa chỉ).
  final String shopName;
  final String shopAddress;
  final String footer;

  Iterable<PrinterConfig> get activePrinters => printers.where((p) => p.enabled);

  Iterable<PrinterConfig> get receiptPrinters => activePrinters.where((p) => p.receipts);

  String encode() => jsonEncode({
        'printers': printers.map((p) => p.toJson()).toList(),
        'auto_print_kitchen': autoPrintKitchen,
        'auto_print_receipt': autoPrintReceipt,
        'shop_name': shopName,
        'shop_address': shopAddress,
        'footer': footer,
      });

  PrintSettings copyWith({
    List<PrinterConfig>? printers,
    bool? autoPrintKitchen,
    bool? autoPrintReceipt,
    String? shopName,
    String? shopAddress,
    String? footer,
  }) =>
      PrintSettings(
        printers: printers ?? this.printers,
        autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
        autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
        shopName: shopName ?? this.shopName,
        shopAddress: shopAddress ?? this.shopAddress,
        footer: footer ?? this.footer,
      );

  /// Thêm mới hoặc thay máy in cùng id.
  PrintSettings upsertPrinter(PrinterConfig printer) {
    final list = [...printers];
    final i = list.indexWhere((p) => p.id == printer.id);
    if (i >= 0) {
      list[i] = printer;
    } else {
      list.add(printer);
    }
    return copyWith(printers: list);
  }

  PrintSettings removePrinter(String id) => copyWith(printers: printers.where((p) => p.id != id).toList());
}
