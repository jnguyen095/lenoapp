import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../core/format.dart';
import 'display_models.dart';

const _brand = Color(0xFF0190DB);
const _brandDark = Color(0xFF016FA9);
const _ink = Color(0xFF1B1F24);
const _muted = Color(0xFF6B7280);
const _paper = Color(0xFFF6F8FB);

/// Màn hình khách: vẽ [snapshot] theo [content]. Dùng cho màn hình phụ của máy POS
/// (CustomerDisplayApp) và cho "Xem thử" trong cài đặt.
class CustomerDisplayView extends StatelessWidget {
  const CustomerDisplayView({super.key, required this.content, required this.snapshot});

  final DisplayContent content;
  final DisplaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Mọi cỡ chữ/khoảng cách tính theo cạnh ngắn của màn hình -> tự vừa màn hình 7" hay TV;
      // nhân thêm cỡ chữ chọn trên web.
      final u = (c.biggest.shortestSide / 100) * content.config.textScale;
      final landscape = c.maxWidth >= c.maxHeight;
      final child = switch (snapshot.state) {
        DisplayState.idle => _IdleView(content: content, u: u),
        DisplayState.order => _OrderView(snapshot: snapshot, shopName: content.shopName, u: u, landscape: landscape),
        DisplayState.paying => _PayingView(snapshot: snapshot, u: u, landscape: landscape),
        DisplayState.thanks => _ThanksView(snapshot: snapshot, text: content.config.thanksText, u: u),
      };
      return ColoredBox(
        color: _paper,
        child: DefaultTextStyle(
          style: TextStyle(color: _ink, fontSize: 3.2 * u, fontFamily: DefaultTextStyle.of(context).style.fontFamily),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(key: ValueKey(snapshot.state), child: child),
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Lúc rảnh: trình chiếu ảnh (hoặc logo + lời chào nếu chưa có ảnh).

class _IdleView extends StatefulWidget {
  const _IdleView({required this.content, required this.u});

  final DisplayContent content;
  final double u;

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  int _index = 0;
  Timer? _timer;

  List<DisplaySlide> get _slides => widget.content.readySlides;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _IdleView old) {
    super.didUpdateWidget(old);
    if (_index >= _slides.length) _index = 0;
    if (old.content.version != widget.content.version) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    final seconds = _slides[_index].durationSeconds ?? widget.content.config.slideSeconds;
    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _slides.length);
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final cfg = widget.content.config;

    if (_slides.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_brand, _brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.all(6 * u),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Logo(size: 30 * u),
            SizedBox(height: 4 * u),
            Text(widget.content.shopName,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 8 * u, fontWeight: FontWeight.w600)),
            if (cfg.welcomeText.isNotEmpty) ...[
              SizedBox(height: 2 * u),
              Text(cfg.welcomeText, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 4.2 * u)),
            ],
          ],
        ),
      );
    }

    final slide = _slides[_index];
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          child: Image.file(
            File(slide.file!),
            key: ValueKey(slide.file),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        if (cfg.showLogo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(4 * u, 8 * u, 4 * u, 3 * u),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
              child: Row(
                children: [
                  _Logo(size: 10 * u),
                  SizedBox(width: 3 * u),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.content.shopName,
                            style: TextStyle(color: Colors.white, fontSize: 4.6 * u, fontWeight: FontWeight.w600)),
                        if (cfg.welcomeText.isNotEmpty)
                          Text(cfg.welcomeText, style: TextStyle(color: Colors.white70, fontSize: 3.2 * u)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      padding: EdgeInsets.all(size * 0.03),
      child: ClipOval(child: Image.asset('assets/images/leno-logo.jpg', fit: BoxFit.cover)),
    );
  }
}

// ---------------------------------------------------------------------------
// Đang gọi món: danh sách món + tổng tiền.

class _OrderView extends StatefulWidget {
  const _OrderView({required this.snapshot, required this.shopName, required this.u, required this.landscape});

  final DisplaySnapshot snapshot;
  final String shopName;
  final double u;
  final bool landscape;

  @override
  State<_OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends State<_OrderView> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _OrderView old) {
    super.didUpdateWidget(old);
    // Món mới thêm nằm cuối danh sách -> cuộn xuống cho khách thấy.
    if (widget.snapshot.lines.length > old.snapshot.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final u = widget.u;

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4 * u, 3.5 * u, 4 * u, 1.5 * u),
          child: Row(
            children: [
              Text('Món đã gọi', style: TextStyle(fontSize: 4.6 * u, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.4 * u, vertical: 0.8 * u),
                decoration: BoxDecoration(border: Border.all(color: _brand, width: 2), borderRadius: BorderRadius.circular(2 * u)),
                child: Text(s.tableName, style: TextStyle(fontSize: 3.8 * u, color: _brand, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: s.lines.isEmpty
              ? Center(child: Text('Đang chờ gọi món…', style: TextStyle(color: _muted, fontSize: 3.6 * u)))
              : ListView.separated(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(4 * u, 0, 4 * u, 3 * u),
                  itemCount: s.lines.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
                  itemBuilder: (context, i) => _LineRow(line: s.lines[i], u: u),
                ),
        ),
      ],
    );

    final summary = Container(
      color: _brand,
      padding: EdgeInsets.all(4 * u),
      child: Column(
        mainAxisAlignment: widget.landscape ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.landscape) ...[
            Center(child: _Logo(size: 14 * u)),
            SizedBox(height: 1.5 * u),
            Text(widget.shopName,
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 4.2 * u, fontWeight: FontWeight.w600)),
            SizedBox(height: 4 * u),
          ],
          _SumRow('Số món', '${s.itemCount}', u: u),
          _SumRow('Tạm tính', formatMoney(s.subtotal), u: u),
          if (s.discount > 0) _SumRow('Chiết khấu', '-${formatMoney(s.discount)}', u: u),
          Divider(color: Colors.white.withValues(alpha: 0.4), height: 3 * u),
          Text('TỔNG CỘNG', style: TextStyle(color: Colors.white70, fontSize: 3.4 * u)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(s.total),
                style: TextStyle(color: Colors.white, fontSize: 10 * u, fontWeight: FontWeight.w700, height: 1.1)),
          ),
        ],
      ),
    );

    return widget.landscape
        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 62, child: list), Expanded(flex: 38, child: summary)])
        : Column(children: [Expanded(child: list), summary]);
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.u});

  final DisplayLine line;
  final double u;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.6 * u),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: BoxConstraints(minWidth: 7 * u),
            padding: EdgeInsets.symmetric(horizontal: 1.2 * u, vertical: 0.5 * u),
            decoration: BoxDecoration(color: _brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(1.5 * u)),
            child: Text('${line.qty}×',
                textAlign: TextAlign.center, style: TextStyle(color: _brandDark, fontSize: 3.4 * u, fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 2.5 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: TextStyle(fontSize: 3.6 * u)),
                if ((line.note ?? '').isNotEmpty)
                  Text(line.note!, style: TextStyle(fontSize: 2.8 * u, color: _muted, fontStyle: FontStyle.italic)),
                Text(formatMoney(line.price), style: TextStyle(fontSize: 2.6 * u, color: _muted)),
              ],
            ),
          ),
          Text(formatMoney(line.amount), style: TextStyle(fontSize: 3.6 * u, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow(this.label, this.value, {required this.u});

  final String label;
  final String value;
  final double u;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: Colors.white, fontSize: 3.4 * u);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.4 * u),
      child: Row(children: [Text(label, style: style), const Spacer(), Text(value, style: style)]),
    );
  }
}

// ---------------------------------------------------------------------------
// Thanh toán chuyển khoản: mã VietQR lớn + số tiền + tài khoản nhận.

class _PayingView extends StatelessWidget {
  const _PayingView({required this.snapshot, required this.u, required this.landscape});

  final DisplaySnapshot snapshot;
  final double u;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final qr = Container(
      padding: EdgeInsets.all(2 * u),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3 * u),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3 * u, offset: Offset(0, u))],
      ),
      child: AspectRatio(aspectRatio: 1, child: QrView(data: s.qrPayload ?? '')),
    );

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text('Quét mã để thanh toán', style: TextStyle(fontSize: 5 * u, fontWeight: FontWeight.w600)),
        SizedBox(height: 1 * u),
        Text('Mở ứng dụng ngân hàng hoặc ví điện tử và quét mã',
            textAlign: landscape ? TextAlign.left : TextAlign.center, style: TextStyle(color: _muted, fontSize: 3 * u)),
        SizedBox(height: 4 * u),
        Text('Số tiền', style: TextStyle(color: _muted, fontSize: 3.2 * u)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(formatMoney(s.total), style: TextStyle(color: _brand, fontSize: 11 * u, fontWeight: FontWeight.w700, height: 1.1)),
        ),
        SizedBox(height: 3 * u),
        if ((s.bankName ?? '').isNotEmpty || (s.accountNo ?? '').isNotEmpty)
          Text('${s.bankName ?? ''} - ${s.accountNo ?? ''}', style: TextStyle(fontSize: 3.6 * u)),
        if ((s.accountName ?? '').isNotEmpty) Text(s.accountName!, style: TextStyle(fontSize: 3.6 * u, fontWeight: FontWeight.w600)),
        if ((s.orderNo ?? '').isNotEmpty) ...[
          SizedBox(height: 1.5 * u),
          Text('Nội dung: ${s.orderNo}', style: TextStyle(color: _muted, fontSize: 3 * u)),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(5 * u),
      alignment: Alignment.center, // giữa màn hình theo cả hai chiều
      child: landscape
          ? Row(
              children: [
                SizedBox(width: 70 * u, child: qr),
                SizedBox(width: 6 * u),
                Expanded(child: info),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 70 * u, child: qr),
                SizedBox(height: 5 * u),
                info,
              ],
            ),
    );
  }
}

/// Mã QR vẽ bằng CustomPaint (nền trắng, có vùng trắng quanh mã theo chuẩn).
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _QrPainter(data), size: Size.infinite);
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data) : _image = data.isEmpty ? null : QrImage(QrCode(payload: QrPayload.fromString(data)));

  final String data;
  final QrImage? _image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final img = _image;
    if (img == null) return;
    const quiet = 2;
    final cells = img.moduleCount + quiet * 2;
    final cell = size.shortestSide / cells;
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < img.moduleCount; y++) {
      for (var x = 0; x < img.moduleCount; x++) {
        if (img.isDark(y, x)) {
          canvas.drawRect(Rect.fromLTWH((x + quiet) * cell, (y + quiet) * cell, cell + 0.5, cell + 0.5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}

// ---------------------------------------------------------------------------
// Thanh toán xong: lời cảm ơn (+ tiền thối nếu trả tiền mặt).

class _ThanksView extends StatelessWidget {
  const _ThanksView({required this.snapshot, required this.text, required this.u});

  final DisplaySnapshot snapshot;
  final String text;
  final double u;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(6 * u),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22 * u,
              height: 22 * u,
              decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 16 * u),
            ),
            SizedBox(height: 4 * u),
            Text(text.isEmpty ? 'Cảm ơn quý khách!' : text,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 6.5 * u, fontWeight: FontWeight.w600)),
            SizedBox(height: 3 * u),
            Text('Đã thanh toán ${formatMoney(s.total)}${s.methodLabel == null ? '' : ' · ${s.methodLabel}'}',
                textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 3.6 * u)),
            if ((s.change ?? 0) > 0) ...[
              SizedBox(height: 3 * u),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5 * u, vertical: 2 * u),
                decoration: BoxDecoration(color: _brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3 * u)),
                child: Column(
                  children: [
                    Text('Tiền thối lại', style: TextStyle(color: _muted, fontSize: 3.2 * u)),
                    Text(formatMoney(s.change!), style: TextStyle(color: _brandDark, fontSize: 9 * u, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
