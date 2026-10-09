// Dữ liệu cho màn hình khách (màn hình phụ của máy POS). Ứng dụng chính dựng [DisplaySnapshot]
// rồi gửi dạng JSON sang màn hình phụ; màn hình phụ chỉ việc vẽ, không tự tính gì.

/// Tuỳ chọn từ web (Quản trị → Màn hình khách), xem GET /api/v1/display/config.
class DisplayConfig {
  const DisplayConfig({
    this.slideSeconds = 8,
    this.showLogo = true,
    this.welcomeText = 'Chào mừng quý khách',
    this.thanksText = 'Cảm ơn quý khách - Hẹn gặp lại!',
    this.thanksSeconds = 6,
    this.showItemNotes = false,
    this.showQr = true,
    this.textScale = 1,
  });

  factory DisplayConfig.fromJson(Map<String, dynamic> j) => DisplayConfig(
        slideSeconds: (j['slide_seconds'] as num?)?.toInt() ?? 8,
        showLogo: j['show_logo'] != false,
        welcomeText: (j['welcome_text'] as String?) ?? '',
        thanksText: (j['thanks_text'] as String?) ?? '',
        thanksSeconds: (j['thanks_seconds'] as num?)?.toInt() ?? 6,
        showItemNotes: j['show_item_notes'] == true,
        showQr: j['show_qr'] != false,
        textScale: (j['text_scale'] as num?)?.toDouble() ?? 1,
      );

  final int slideSeconds;
  final bool showLogo;
  final String welcomeText;
  final String thanksText;
  final int thanksSeconds;
  final bool showItemNotes;
  final bool showQr;
  final double textScale;

  Map<String, dynamic> toJson() => {
        'slide_seconds': slideSeconds,
        'show_logo': showLogo,
        'welcome_text': welcomeText,
        'thanks_text': thanksText,
        'thanks_seconds': thanksSeconds,
        'show_item_notes': showItemNotes,
        'show_qr': showQr,
        'text_scale': textScale,
      };
}

/// Ảnh trình chiếu. [url] = đường dẫn trên máy chủ (assets/...), [file] = bản đã tải về máy.
class DisplaySlide {
  const DisplaySlide({required this.id, required this.url, this.file, this.title, this.durationSeconds, this.updatedAt});

  factory DisplaySlide.fromJson(Map<String, dynamic> j) => DisplaySlide(
        id: (j['id'] as num).toInt(),
        url: (j['image'] as String?) ?? '',
        file: j['file'] as String?,
        title: j['title'] as String?,
        durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
        updatedAt: j['updated_at'] as String?,
      );

  final int id;
  final String url;
  final String? file;
  final String? title;
  final int? durationSeconds;
  final String? updatedAt;

  DisplaySlide withFile(String? path) =>
      DisplaySlide(id: id, url: url, file: path, title: title, durationSeconds: durationSeconds, updatedAt: updatedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'image': url,
        'file': file,
        'title': title,
        'duration_seconds': durationSeconds,
        'updated_at': updatedAt,
      };
}

/// Nội dung lúc rảnh: tên quán + tuỳ chọn + ảnh (đã tải về máy).
class DisplayContent {
  const DisplayContent({this.shopName = 'Leno', this.config = const DisplayConfig(), this.slides = const [], this.version = ''});

  factory DisplayContent.fromJson(Map<String, dynamic> j) => DisplayContent(
        shopName: (j['shop_name'] as String?) ?? 'Leno',
        config: DisplayConfig.fromJson((j['config'] as Map?)?.cast<String, dynamic>() ?? const {}),
        slides: ((j['slides'] as List?) ?? const [])
            .map((s) => DisplaySlide.fromJson((s as Map).cast<String, dynamic>()))
            .toList(growable: false),
        version: (j['version'] as String?) ?? '',
      );

  final String shopName;
  final DisplayConfig config;
  final List<DisplaySlide> slides;
  final String version;

  /// Chỉ các ảnh đã có file trên máy (ảnh tải lỗi thì bỏ qua, không làm trống màn hình).
  List<DisplaySlide> get readySlides => slides.where((s) => s.file != null).toList(growable: false);

  DisplayContent copyWith({String? shopName, DisplayConfig? config, List<DisplaySlide>? slides, String? version}) =>
      DisplayContent(
        shopName: shopName ?? this.shopName,
        config: config ?? this.config,
        slides: slides ?? this.slides,
        version: version ?? this.version,
      );

  Map<String, dynamic> toJson() => {
        'shop_name': shopName,
        'config': config.toJson(),
        'slides': slides.map((s) => s.toJson()).toList(),
        'version': version,
      };
}

enum DisplayState { idle, order, paying, thanks }

class DisplayLine {
  const DisplayLine({required this.name, required this.qty, required this.price, required this.amount, this.note});

  factory DisplayLine.fromJson(Map<String, dynamic> j) => DisplayLine(
        name: j['name'] as String,
        qty: (j['qty'] as num).toInt(),
        price: (j['price'] as num).toDouble(),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String?,
      );

  final String name;
  final int qty;
  final double price;
  final double amount;
  final String? note;

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'price': price, 'amount': amount, 'note': note};
}

/// Những gì khách đang thấy. Không chứa tên nhân viên hay thông tin nội bộ.
class DisplaySnapshot {
  const DisplaySnapshot({
    this.state = DisplayState.idle,
    this.orderId,
    this.tableName = '',
    this.lines = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.qrPayload,
    this.bankName,
    this.accountNo,
    this.accountName,
    this.orderNo,
    this.methodLabel,
    this.received,
    this.change,
  });

  const DisplaySnapshot.idle() : this();

  factory DisplaySnapshot.fromJson(Map<String, dynamic> j) => DisplaySnapshot(
        state: DisplayState.values.firstWhere((s) => s.name == j['state'], orElse: () => DisplayState.idle),
        orderId: (j['order_id'] as num?)?.toInt(),
        tableName: (j['table_name'] as String?) ?? '',
        lines: ((j['lines'] as List?) ?? const [])
            .map((l) => DisplayLine.fromJson((l as Map).cast<String, dynamic>()))
            .toList(growable: false),
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        qrPayload: j['qr'] as String?,
        bankName: j['bank_name'] as String?,
        accountNo: j['account_no'] as String?,
        accountName: j['account_name'] as String?,
        orderNo: j['order_no'] as String?,
        methodLabel: j['method_label'] as String?,
        received: (j['received'] as num?)?.toDouble(),
        change: (j['change'] as num?)?.toDouble(),
      );

  final DisplayState state;
  final int? orderId;
  final String tableName;
  final List<DisplayLine> lines;
  final double subtotal;
  final double discount;
  final double total;

  // Đang thanh toán chuyển khoản: chuỗi VietQR + thông tin tài khoản nhận.
  final String? qrPayload;
  final String? bankName;
  final String? accountNo;
  final String? accountName;
  final String? orderNo;

  // Đã thanh toán.
  final String? methodLabel;
  final double? received;
  final double? change;

  int get itemCount => lines.fold(0, (s, l) => s + l.qty);

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'order_id': orderId,
        'table_name': tableName,
        'lines': lines.map((l) => l.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'qr': qrPayload,
        'bank_name': bankName,
        'account_no': accountNo,
        'account_name': accountName,
        'order_no': orderNo,
        'method_label': methodLabel,
        'received': received,
        'change': change,
      };
}
