import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../state/auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  bool _showServer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final store = ref.read(sessionStoreProvider);
    final server = await store.readServerUrl();
    final username = await store.readLastUsername();
    if (!mounted) return;
    setState(() {
      _server.text = server ?? defaultServerUrl;
      _username.text = username ?? '';
    });
    if ((username ?? '').isNotEmpty) _passwordFocus.requestFocus();
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            serverUrl: _server.text,
            username: _username.text,
            password: _password.text,
          );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          // Lỗi kết nối thường do sai địa chỉ máy chủ -> mở sẵn ô máy chủ để sửa.
          if (e.statusCode == null || e.statusCode == 404) _showServer = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập không thành công: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        // Logo tròn trên nền trắng -> cắt tròn để không lộ góc trắng.
                        child: ClipOval(
                          child: Image.asset('assets/images/leno-logo.jpg', width: 128, height: 128, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Leno POS', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                      Text(
                        'Gọi món · Báo bếp · Thanh toán',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _username,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tên đăng nhập' : null,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy ? null : () => setState(() => _showServer = !_showServer),
                          icon: Icon(_showServer ? Icons.expand_less : Icons.dns_outlined, size: 18),
                          label: Text(_showServer
                              ? 'Ẩn địa chỉ máy chủ'
                              : 'Máy chủ: ${ApiClient.normalizeServerUrl(_server.text)}'),
                        ),
                      ),
                      if (_showServer)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: _server,
                            enabled: !_busy,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ máy chủ',
                              helperText: 'Vd: https://leno.pickangelpark.com hoặc http://192.168.1.10/leno',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập địa chỉ máy chủ' : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: _busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Đăng nhập', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
