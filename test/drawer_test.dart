import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leno_pos/models/models.dart';
import 'package:leno_pos/state/auth.dart';
import 'package:leno_pos/ui/widgets/app_drawer.dart';

class _FakeAuth extends AuthController {
  int logoutCalls = 0;

  @override
  Future<Session?> build() async => const Session(
        serverUrl: 'http://localhost/leno',
        token: 't',
        user: User(id: 1, username: 'lan', fullname: 'Lan', role: 'CASHIER', roleLabel: 'Thu ngân',
            canTables: true, canOrders: true),
        settings: ShopSettings(siteName: 'Leno', vatPercent: 0, takeawayEnabled: true),
      );

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(null);
  }
}

void main() {
  late _FakeAuth auth;

  Future<void> openDrawer(WidgetTester tester) async {
    auth = _FakeAuth();
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => auth)],
      child: const MaterialApp(
        home: Scaffold(drawer: AppDrawer(current: AppPage.home), body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('Đăng xuất: confirm logs out and closes the menu', (tester) async {
    await openDrawer(tester);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất khỏi máy này?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('Đăng xuất: cancel keeps the session', (tester) async {
    await openDrawer(tester);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thôi'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 0);
  });
}
