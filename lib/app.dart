import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'state/auth.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Màu chủ đạo: xanh Leno #0190DB (dùng đúng mã này cho primary, các màu phụ sinh từ đó).
const brandColor = Color(0xFF0190DB);

ThemeData buildTheme(Brightness brightness, {String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness).copyWith(
    primary: brandColor,
    onPrimary: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class LenoApp extends StatelessWidget {
  const LenoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leno POS',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// Chọn màn hình theo phiên đăng nhập; hết phiên thì đóng mọi màn hình đang mở về đăng nhập.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (prev, next) {
      final wasLoggedIn = prev?.valueOrNull != null;
      if (wasLoggedIn && next.hasValue && next.value == null) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    return ref.watch(authProvider).when(
          skipLoadingOnRefresh: false,
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ConnectionErrorScreen(
            message: error is ApiException ? error.message : 'Không kết nối được máy chủ.',
          ),
          data: (session) => session == null ? const LoginScreen() : const HomeScreen(),
        );
  }
}

class _ConnectionErrorScreen extends ConsumerWidget {
  const _ConnectionErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(authProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Đăng nhập lại / đổi máy chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
