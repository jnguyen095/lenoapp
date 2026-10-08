/// Chuỗi dữ liệu VietQR (chuẩn NAPAS, theo EMVCo Merchant-Presented QR) để khách quét bằng ứng dụng
/// ngân hàng: chuyển khoản tới [accountNo] của ngân hàng [bankBin], điền sẵn số tiền và nội dung.
///
/// Mỗi trường là ID (2 số) + độ dài (2 số) + giá trị; cuối chuỗi là mã kiểm tra CRC-16 (trường 63).
String buildVietQr({
  required String bankBin,
  required String accountNo,
  int? amount,
  String? purpose,
}) {
  String field(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

  final consumer = field('00', bankBin) + field('01', accountNo);
  final merchantAccount = field('00', 'A000000727') // định danh NAPAS
      + field('01', consumer)
      + field('02', 'QRIBFTTA'); // dịch vụ: chuyển nhanh 24/7 tới tài khoản

  final note = purpose == null ? '' : _cleanPurpose(purpose);
  final hasAmount = amount != null && amount > 0;

  final payload = StringBuffer()
    ..write(field('00', '01')) // phiên bản
    ..write(field('01', hasAmount ? '12' : '11')) // 12 = mã động (dùng 1 lần, có số tiền), 11 = mã tĩnh
    ..write(field('38', merchantAccount))
    ..write(field('53', '704')) // VND
    ..write(hasAmount ? field('54', '$amount') : '')
    ..write(field('58', 'VN'))
    ..write(note.isEmpty ? '' : field('62', field('08', note)))
    ..write('6304');

  return '$payload${crc16Ccitt(payload.toString()).toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

/// Nội dung chuyển khoản: chỉ chữ không dấu, số, khoảng trắng và gạch ngang (ứng dụng ngân hàng
/// nào cũng nhận), tối đa 25 ký tự.
String _cleanPurpose(String s) {
  final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').trim();
  return cleaned.length > 25 ? cleaned.substring(0, 25) : cleaned;
}

/// CRC-16/CCITT-FALSE (đa thức 0x1021, giá trị đầu 0xFFFF) — mã kiểm tra bắt buộc của VietQR.
int crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= (byte & 0xFF) << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}
