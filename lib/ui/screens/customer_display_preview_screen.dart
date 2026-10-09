import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer_display/customer_display_controller.dart';
import '../../customer_display/customer_display_view.dart';
import '../../customer_display/display_models.dart';
import '../../printing/vietqr.dart';
import '../../state/auth.dart';

enum _PreviewMode { live, idle, order, paying, thanks }

/// Xem thử màn hình khách ngay trên máy này (không cần màn hình phụ): nội dung thật (ảnh, tuỳ chọn)
/// + trạng thái đang hiện, hoặc các trạng thái mẫu.
class CustomerDisplayPreviewScreen extends ConsumerStatefulWidget {
  const CustomerDisplayPreviewScreen({super.key});

  @override
  ConsumerState<CustomerDisplayPreviewScreen> createState() => _CustomerDisplayPreviewScreenState();
}

class _CustomerDisplayPreviewScreenState extends ConsumerState<CustomerDisplayPreviewScreen> {
  _PreviewMode _mode = _PreviewMode.live;

  static const _sampleLines = [
    DisplayLine(name: 'Cà phê sữa đá', qty: 2, price: 18000, amount: 36000, note: 'Ít đá'),
    DisplayLine(name: 'Trà đào cam sả', qty: 1, price: 28000, amount: 28000),
    DisplayLine(name: 'Bánh mì ốp la', qty: 1, price: 20000, amount: 20000),
  ];

  DisplaySnapshot _sample(_PreviewMode mode) {
    const order = DisplaySnapshot(
      state: DisplayState.order,
      orderId: 0,
      tableName: 'Bàn 3',
      lines: _sampleLines,
      subtotal: 84000,
      total: 84000,
    );
    switch (mode) {
      case _PreviewMode.order:
        return order;
      case _PreviewMode.paying:
        final bank = ref.read(authProvider).valueOrNull?.settings.bankQr;
        return DisplaySnapshot(
          state: DisplayState.paying,
          orderId: 0,
          tableName: order.tableName,
          lines: order.lines,
          subtotal: order.subtotal,
          total: order.total,
          orderNo: 'ORD-XEM-THU',
          // Mã mẫu: đúng tài khoản đã cài, nhưng là mã xem thử (nội dung ORD-XEM-THU).
          qrPayload: bank == null || !bank.enabled
              ? null
              : buildVietQr(bankBin: bank.bin, accountNo: bank.accountNo, amount: 84000, purpose: 'ORD-XEM-THU'),
          bankName: bank?.bankName,
          accountNo: bank?.accountNo,
          accountName: bank?.accountName,
        );
      case _PreviewMode.thanks:
        return const DisplaySnapshot(
          state: DisplayState.thanks,
          orderId: 0,
          tableName: 'Bàn 3',
          total: 84000,
          methodLabel: 'Tiền mặt',
          received: 100000,
          change: 16000,
        );
      case _PreviewMode.idle:
      case _PreviewMode.live:
        return const DisplaySnapshot.idle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = ref.watch(customerDisplayProvider);
    final snapshot = _mode == _PreviewMode.live ? display.snapshot : _sample(_mode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem thử màn hình khách'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<_PreviewMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _PreviewMode.live, label: Text('Đang hiện')),
                ButtonSegment(value: _PreviewMode.idle, label: Text('Lúc rảnh')),
                ButtonSegment(value: _PreviewMode.order, label: Text('Gọi món')),
                ButtonSegment(value: _PreviewMode.paying, label: Text('Chuyển khoản')),
                ButtonSegment(value: _PreviewMode.thanks, label: Text('Cảm ơn')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
        ),
      ),
      body: CustomerDisplayView(content: display.content, snapshot: snapshot),
    );
  }
}
