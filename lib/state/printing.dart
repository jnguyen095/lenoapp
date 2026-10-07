import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../printing/print_settings.dart';
import '../printing/printer_service.dart';
import '../printing/ticket.dart';
import '../printing/tickets.dart';
import 'pos.dart';

const _settingsKey = 'print_settings';

/// Cấu hình máy in của máy này (SharedPreferences).
final printSettingsProvider = AsyncNotifierProvider<PrintSettingsController, PrintSettings>(PrintSettingsController.new);

class PrintSettingsController extends AsyncNotifier<PrintSettings> {
  @override
  Future<PrintSettings> build() async =>
      PrintSettings.decode((await SharedPreferences.getInstance()).getString(_settingsKey));

  Future<void> save(PrintSettings settings) async {
    state = AsyncData(settings);
    await (await SharedPreferences.getInstance()).setString(_settingsKey, settings.encode());
  }

  Future<void> change(PrintSettings Function(PrintSettings current) edit) async =>
      save(edit(state.valueOrNull ?? await future));
}

final printerServiceProvider = Provider<PrinterService>((ref) => PrinterService());

final printActionsProvider = Provider<PrintActions>((ref) => PrintActions(ref));

/// Kết quả một lần in: số phiếu đã in, lỗi (máy in không kết nối được...) và cảnh báo.
class PrintReport {
  PrintReport();

  int printed = 0;
  final errors = <String>[];
  final warnings = <String>[];

  bool get ok => errors.isEmpty;

  /// Chưa cài máy in nào phù hợp -> không coi là lỗi, chỉ nhắc.
  bool notConfigured = false;
}

/// Các lệnh in dùng ở màn hình đơn: phiếu bếp (tách theo danh mục), tạm tính, hóa đơn.
class PrintActions {
  PrintActions(this._ref);

  final Ref _ref;

  PrinterService get _service => _ref.read(printerServiceProvider);

  Future<PrintSettings> _settings() => _ref.read(printSettingsProvider.future);

  /// product_id -> category_id theo thực đơn đang tải; món đã ngừng bán thì không biết danh mục.
  Future<Map<int, int>> _productCategories() async {
    try {
      final menu = await _ref.read(menuProvider.future);
      return {
        for (final c in menu)
          for (final p in c.products) p.id: c.id,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _run(PrintReport report, PrinterConfig printer, Ticket ticket) async {
    try {
      await _service.printTicket(printer, ticket);
      report.printed++;
    } on PrintException catch (e) {
      report.errors.add(e.message);
    } catch (e) {
      report.errors.add('Máy in "${printer.name}": $e');
    }
  }

  Future<PrintReport> kitchen(KitchenSlip slip, Order order) async {
    final report = PrintReport();
    final settings = await _settings();
    if (settings.activePrinters.isEmpty) {
      report.notConfigured = true;
      return report;
    }

    final categories = await _productCategories();
    final route = routeKitchenSlip(slip, settings.activePrinters, (id) => categories[id]);
    if (route.unrouted.isNotEmpty) {
      report.warnings.add('Không có máy in cho: ${route.unrouted.map((l) => l.productName).toSet().join(', ')}. '
          'Hãy gán danh mục hoặc chọn một "Máy bếp mặc định" trong Cài đặt máy in.');
    }
    // Các máy in khác nhau in song song; cùng một máy thì hàng đợi trong PrinterService lo.
    await Future.wait([
      for (final (printer, part) in route.jobs) _run(report, printer, Tickets.kitchen(part, order, station: printer.name)),
    ]);
    return report;
  }

  /// Phiếu tạm tính (đơn đang mở) hoặc hóa đơn (đơn đã thanh toán) ra các máy "In hóa đơn".
  Future<PrintReport> bill(OrderDetail detail) async {
    final report = PrintReport();
    final settings = await _settings();
    final printers = settings.receiptPrinters.toList();
    if (printers.isEmpty) {
      report.notConfigured = true;
      return report;
    }
    final ticket = Tickets.bill(detail, settings);
    await Future.wait([for (final p in printers) _run(report, p, ticket)]);
    return report;
  }

  Future<PrintReport> test(PrinterConfig printer) async {
    final report = PrintReport();
    Map<int, String> names = const {};
    try {
      names = {for (final c in await _ref.read(menuProvider.future)) c.id: c.name};
    } catch (_) {}
    await _run(report, printer, Tickets.test(printer, categoryNames: names));
    return report;
  }
}
