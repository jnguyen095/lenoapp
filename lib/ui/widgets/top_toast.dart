import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _current;

/// Thông báo ngắn trượt xuống ở đầu màn hình, tự ẩn sau [duration] (không che nút ở cuối màn hình).
/// Bấm vào thông báo -> [onTap] (vd mở lịch sử báo bếp).
void showTopToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  String? actionLabel,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;

  late final OverlayEntry entry;
  void close() {
    if (_current == entry) _current = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _TopToast(
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      duration: duration,
      onTap: onTap == null
          ? null
          : () {
              close();
              onTap();
            },
      onDone: close,
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDone,
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDone;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.2), end: Offset.zero)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: scheme.inverseSurface,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onTap ?? _hide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(widget.icon, color: scheme.inversePrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(widget.message, style: TextStyle(color: scheme.onInverseSurface)),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 8),
                            Text(widget.actionLabel!,
                                style: TextStyle(color: scheme.inversePrimary, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
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
