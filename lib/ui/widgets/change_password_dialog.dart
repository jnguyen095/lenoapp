import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../state/auth.dart';
import 'dialogs.dart';

/// Đổi mật khẩu (giống web: Đổi mật khẩu). Xong thì các thiết bị khác phải đăng nhập lại, máy này giữ phiên.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final message = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (message != null && context.mounted) showMessage(context, message);
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final msg = await ref.read(posRepositoryProvider).changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(msg);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
            icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _show = !_show),
          ),
        );

    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _current,
                obscureText: !_show,
                autofocus: true,
                decoration: deco('Mật khẩu hiện tại'),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: !_show,
                decoration: deco('Mật khẩu mới').copyWith(helperText: 'Ít nhất 6 ký tự'),
                validator: (v) {
                  if ((v ?? '').length < 6) return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                  if (v == _current.text) return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: !_show,
                decoration: deco('Nhập lại mật khẩu mới'),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => v != _next.text ? 'Xác nhận mật khẩu mới không khớp' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 8),
              Text(
                'Sau khi đổi, các máy khác đang đăng nhập tài khoản này sẽ phải đăng nhập lại.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Thôi')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}
