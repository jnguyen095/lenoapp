import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_drawer.dart';
import '../widgets/dialogs.dart';

/// Hỗ trợ: thông tin liên hệ đơn vị làm phần mềm. Bấm số điện thoại / email để sao chép.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const brand = 'K-Soft';
  static const phone = '0367139698';
  static const email = 'nguyennhukhangvn@gmail.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Future<void> copy(String label, String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) showMessage(context, 'Đã sao chép $label: $value');
    }

    Widget row(IconData icon, String label, String value, {bool copyable = true}) => ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, color: scheme.primary),
          ),
          title: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          // Một dòng, chữ tự nhỏ lại nếu dài (email trên điện thoại).
          subtitle: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          trailing: copyable
              ? IconButton(
                  tooltip: 'Sao chép',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => copy(label.toLowerCase(), value),
                )
              : null,
          onTap: copyable ? () => copy(label.toLowerCase(), value) : null,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ'), actions: const [AppMenuButton()]),
      endDrawer: const AppDrawer(current: AppPage.support),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Icon(Icons.support_agent, size: 64, color: scheme.primary),
              const SizedBox(height: 12),
              Text('Cần hỗ trợ?', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Liên hệ đơn vị phát triển phần mềm khi gặp sự cố hoặc cần hướng dẫn.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: Column(
                  children: [
                    row(Icons.business_outlined, 'Đơn vị', brand, copyable: false),
                    const Divider(height: 1, indent: 72),
                    row(Icons.phone_outlined, 'Điện thoại', phone),
                    const Divider(height: 1, indent: 72),
                    row(Icons.email_outlined, 'Email', email),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
