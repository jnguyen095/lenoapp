import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../printing/vietqr.dart';
import '../state/auth.dart';
import '../state/printing.dart';
import 'display_bridge.dart';
import 'display_models.dart';
import 'slide_cache.dart';

/// Trạng thái màn hình khách mà ứng dụng chính đang điều khiển.
class CustomerDisplayState {
  const CustomerDisplayState({
    this.enabled = true,
    this.info = SecondaryDisplayInfo.none,
    this.content = const DisplayContent(),
    this.snapshot = const DisplaySnapshot.idle(),
    this.lastError,
  });

  /// Bật hiển thị trên màn hình phụ (cài đặt trên máy này).
  final bool enabled;
  final SecondaryDisplayInfo info;
  final DisplayContent content;
  final DisplaySnapshot snapshot;

  /// Lỗi tải ảnh/tuỳ chọn lần gần nhất (để hiện trong cài đặt).
  final String? lastError;

  CustomerDisplayState copyWith({
    bool? enabled,
    SecondaryDisplayInfo? info,
    DisplayContent? content,
    DisplaySnapshot? snapshot,
    String? lastError,
    bool clearError = false,
  }) =>
      CustomerDisplayState(
        enabled: enabled ?? this.enabled,
        info: info ?? this.info,
        content: content ?? this.content,
        snapshot: snapshot ?? this.snapshot,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

final displayBridgeProvider = Provider<DisplayBridge>((ref) => DisplayBridge());
final slideCacheProvider = Provider<SlideCache>((ref) => SlideCache());

/// Điều khiển màn hình khách: lúc rảnh trình chiếu ảnh, đang gọi món hiện danh sách món,
/// thanh toán chuyển khoản hiện VietQR, thanh toán xong hiện lời cảm ơn rồi về lúc rảnh.
final customerDisplayProvider =
    NotifierProvider<CustomerDisplayController, CustomerDisplayState>(CustomerDisplayController.new);

class CustomerDisplayController extends Notifier<CustomerDisplayState> {
  static const _enabledKey = 'customer_display_enabled';
  static const refreshEvery = Duration(minutes: 5);

  Timer? _refreshTimer;
  Timer? _thanksTimer;
  OrderDetail? _lastOrder; // đơn đang hiện (để quay lại từ màn hình QR)
  bool _started = false;

  DisplayBridge get _bridge => ref.read(displayBridgeProvider);

  @override
  CustomerDisplayState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _thanksTimer?.cancel();
    });
    // Đăng xuất -> về màn hình chờ; lần đăng nhập sau (có thể máy chủ khác) khởi động lại từ đầu.
    ref.listen(authProvider, (prev, next) {
      if (next.valueOrNull == null) {
        _refreshTimer?.cancel();
        _started = false;
        _lastOrder = null;
        _show(const DisplaySnapshot.idle());
      }
    });
    return const CustomerDisplayState();
  }

  /// Gọi một lần sau khi đăng nhập (màn hình chính): bật màn hình phụ, tải ảnh, hẹn giờ tải lại.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;
    state = state.copyWith(enabled: enabled);
    await _bridge.setEnabled(enabled);
    await refreshStatus();
    await refreshContent();
    _refreshTimer = Timer.periodic(refreshEvery, (_) => refreshContent());
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, enabled);
    await _bridge.setEnabled(enabled);
    await refreshStatus();
    // Gửi lại nội dung cho màn hình phụ vừa bật.
    await _bridge.sendContent(state.content);
    await _bridge.sendSnapshot(state.snapshot);
  }

  Future<void> refreshStatus() async {
    state = state.copyWith(info: await _bridge.status());
  }

  /// Tải tuỳ chọn + ảnh trình chiếu từ máy chủ, lưu ảnh xuống máy, gửi sang màn hình phụ.
  Future<void> refreshContent() async {
    final session = ref.read(authProvider).valueOrNull;
    if (session == null) return;
    final shopName = (await ref.read(printSettingsProvider.future)).shopName;
    try {
      final api = ref.read(apiClientProvider);
      final res = await ref.read(posRepositoryProvider).displayConfig();
      final fresh = DisplayContent.fromJson({
        'shop_name': shopName,
        'config': res['config'],
        'slides': res['slides'],
        'version': res['version'],
      });
      final slides = await ref.read(slideCacheProvider).sync(fresh.slides, api.downloadBytes);
      state = state.copyWith(content: fresh.copyWith(slides: slides), clearError: true);
    } catch (e) {
      // Máy chủ cũ chưa có API / mất mạng: giữ nội dung cũ, chỉ cập nhật tên quán.
      state = state.copyWith(content: state.content.copyWith(shopName: shopName), lastError: '$e');
    }
    await _bridge.sendContent(state.content);
  }

  // ---- Các bước của một đơn ----

  /// Màn hình đơn đang mở / đơn vừa thay đổi.
  void showOrder(OrderDetail detail) {
    if (!detail.isActive) return;
    _lastOrder = detail;
    final s = state.snapshot;
    if (s.state == DisplayState.paying && s.orderId == detail.order.id) {
      // Đang hiện QR mà đơn đổi (máy khác thêm món) -> cập nhật số tiền trên QR.
      startPaying(detail, PaymentMethod.transfer);
      return;
    }
    if (s.state == DisplayState.thanks) return; // đang cảm ơn khách -> để hết giờ
    _show(_orderSnapshot(detail));
  }

  /// Rời màn hình đơn (quay về sơ đồ bàn).
  void leaveOrder(int orderId) {
    final s = state.snapshot;
    if ((s.state == DisplayState.order || s.state == DisplayState.paying) && s.orderId == orderId) {
      _lastOrder = null;
      _show(const DisplaySnapshot.idle());
    }
  }

  /// Đang chọn hình thức thanh toán: chuyển khoản/QR thì hiện mã VietQR, còn lại hiện danh sách món.
  void startPaying(OrderDetail detail, PaymentMethod method) {
    _lastOrder = detail;
    final bank = ref.read(authProvider).valueOrNull?.settings.bankQr;
    final wantsQr = method == PaymentMethod.transfer || method == PaymentMethod.qr;
    if (!wantsQr || bank == null || !bank.enabled || !state.content.config.showQr || detail.order.totalAmount <= 0) {
      _show(_orderSnapshot(detail));
      return;
    }
    final base = _orderSnapshot(detail);
    _show(DisplaySnapshot(
      state: DisplayState.paying,
      orderId: base.orderId,
      tableName: base.tableName,
      lines: base.lines,
      subtotal: base.subtotal,
      discount: base.discount,
      total: base.total,
      orderNo: detail.order.orderNo,
      qrPayload: buildVietQr(
        bankBin: bank.bin,
        accountNo: bank.accountNo,
        amount: detail.order.totalAmount.round(),
        purpose: detail.order.orderNo,
      ),
      bankName: bank.bankName,
      accountNo: bank.accountNo,
      accountName: bank.accountName,
    ));
  }

  /// Đóng bảng thanh toán mà chưa trả tiền.
  void cancelPaying(int orderId) {
    final last = _lastOrder;
    if (state.snapshot.state == DisplayState.paying && state.snapshot.orderId == orderId && last != null) {
      _show(_orderSnapshot(last));
    }
  }

  /// Đã thanh toán: hiện lời cảm ơn (kèm tiền thối nếu trả tiền mặt) rồi về màn hình chờ.
  void showThanks(OrderDetail paid) {
    _lastOrder = null;
    final p = paid.payment;
    _show(DisplaySnapshot(
      state: DisplayState.thanks,
      orderId: paid.order.id,
      tableName: _tableName(paid.order),
      total: paid.order.totalAmount,
      methodLabel: p?.methodLabel,
      received: p != null && p.method == PaymentMethod.cash.code ? p.receivedAmount : null,
      change: p != null && p.method == PaymentMethod.cash.code ? p.changeAmount : null,
    ));
    _thanksTimer?.cancel();
    _thanksTimer = Timer(Duration(seconds: state.content.config.thanksSeconds), () {
      if (state.snapshot.state == DisplayState.thanks && state.snapshot.orderId == paid.order.id) {
        _show(const DisplaySnapshot.idle());
      }
    });
  }

  /// Chỉ dùng trong test: đặt nội dung như vừa tải từ máy chủ.
  @visibleForTesting
  void debugSetContent(DisplayContent content) => state = state.copyWith(content: content);

  // ---- Nội bộ ----

  static String _tableName(Order o) => o.tableId == null ? 'Mang đi' : o.tableName;

  DisplaySnapshot _orderSnapshot(OrderDetail d) {
    final showNotes = state.content.config.showItemNotes;
    return DisplaySnapshot(
      state: DisplayState.order,
      orderId: d.order.id,
      tableName: _tableName(d.order),
      lines: [
        for (final it in d.items.where((i) => !i.isCancelled))
          DisplayLine(
            name: it.productName,
            qty: it.qty,
            price: it.price,
            amount: it.amount,
            note: showNotes ? it.note : null,
          ),
      ],
      subtotal: d.order.subtotal,
      discount: d.order.discountAmount,
      total: d.order.totalAmount,
    );
  }

  void _show(DisplaySnapshot snapshot) {
    if (snapshot.state != DisplayState.thanks) _thanksTimer?.cancel();
    state = state.copyWith(snapshot: snapshot);
    _bridge.sendSnapshot(snapshot);
  }
}
