import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/printing/vietqr.dart';

void main() {
  test('CRC-16/CCITT-FALSE matches the standard check value', () {
    expect(crc16Ccitt('123456789'), 0x29B1);
  });

  test('builds a dynamic VietQR with amount and order number', () {
    final qr = buildVietQr(
      bankBin: '970415', // VietinBank
      accountNo: '101874640883',
      amount: 175000,
      purpose: 'ORD261008-0192B',
    );

    const expectedWithoutCrc = '000201' // phiên bản
        '010212' // mã động
        '3856' '0010A000000727' '0126' '0006970415' '0112101874640883' '0208QRIBFTTA' // NAPAS + tài khoản
        '5303704' // VND
        '5406175000' // số tiền
        '5802VN'
        '6219' '0815ORD261008-0192B' // nội dung chuyển khoản
        '6304';
    expect(qr.substring(0, qr.length - 4), expectedWithoutCrc);
    expect(qr.substring(qr.length - 4), crc16Ccitt(expectedWithoutCrc).toRadixString(16).toUpperCase().padLeft(4, '0'));
  });

  test('purpose keeps only safe characters and max 25 chars', () {
    final qr = buildVietQr(bankBin: '970415', accountNo: '123456', amount: 1000, purpose: 'Bàn 3 #ORD-1 rất dài quá mức cho phép');
    final note = RegExp(r'62(\d\d)08(\d\d)(.+?)6304').firstMatch(qr)!;
    expect(note.group(3)!.length, int.parse(note.group(2)!));
    expect(note.group(3), 'Bn 3 ORD-1 rt di qu mc ch');
  });

  test('static QR (no amount) uses initiation method 11 and omits field 54', () {
    final qr = buildVietQr(bankBin: '970415', accountNo: '101874640883');
    expect(qr.startsWith('000201010211'), isTrue);
    expect(qr.contains('5406'), isFalse);
  });
}
