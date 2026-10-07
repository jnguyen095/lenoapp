/// Định dạng tiền và thời gian theo kiểu web Leno (45.000 đ).
String formatMoney(num amount, {bool withUnit = true}) {
  final negative = amount < 0;
  final digits = amount.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buf${withUnit ? '' : ''}';
}

const _vnGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _vnFold = {
  for (final e in _vnGroups.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Chữ thường, bỏ dấu tiếng Việt — để tìm "ca phe sua" ra "Cà phê sữa".
String foldVietnamese(String input) =>
    input.toLowerCase().split('').map((c) => _vnFold[c] ?? c).join();

/// "2026-10-07 09:19:09" (giờ máy chủ) -> DateTime.
DateTime? parseServerTime(String? value) =>
    value == null || value.isEmpty ? null : DateTime.tryParse(value.replaceFirst(' ', 'T'));

String formatTime(String? value) {
  final t = parseServerTime(value);
  if (t == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}';
}

/// "07/10/2026 09:19" — như trên hóa đơn web. Không có giá trị thì lấy giờ hiện tại.
String formatDateTime(String? value) {
  final t = parseServerTime(value) ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

