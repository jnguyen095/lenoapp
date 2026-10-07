import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/ui/widgets/table_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 200, height: 140, child: child))),
      );

  testWidgets('TableCard shows a free table', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(TableCard(
      table: const PosTable(
        id: 1, code: 'T01', name: 'Bàn 1', note: null, capacity: 4,
        isTakeaway: false, status: Status.available, order: null,
      ),
      onTap: () => tapped = true,
    )));

    expect(find.text('Bàn 1'), findsOneWidget);
    expect(find.text('Trống'), findsNothing); // trạng thái chỉ thể hiện bằng màu
    expect(find.text('4 chỗ'), findsNothing);

    await tester.tap(find.byType(TableCard));
    expect(tapped, isTrue);
  });

  testWidgets('TableCard shows the open order total', (tester) async {
    await tester.pumpWidget(wrap(const TableCard(
      table: PosTable(
        id: 2, code: 'T02', name: 'Bàn 2', note: 'Gần cửa sổ', capacity: 4,
        isTakeaway: false, status: Status.open,
        order: OrderSummary(id: 80, orderNo: 'ORD1', status: Status.open, totalAmount: 58000),
      ),
    )));

    expect(find.text('58.000'), findsOneWidget);
    expect(find.text('Đang phục vụ'), findsNothing);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing); // chỉ bàn Mang đi có biểu tượng
  });
}
