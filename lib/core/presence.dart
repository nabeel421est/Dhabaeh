import 'dart:async';

import 'package:flutter/widgets.dart';

import 'common.dart';

/// Tells «مراقبة وتتبع العملاء» where the customer is in the app.
/// The shell sets the base place (its tab); pages push their own place on top
/// with [PresenceTag]. A heartbeat every 30 s keeps the customer «online».
class Presence {
  static final _stack = <(String, String?, String?)>[];
  static (String, String?, String?) _base = ('الرئيسية · الملاحم', null, null);
  static Timer? _beat;
  static AppLifecycleListener? _life;
  static bool _on = false;

  static void start() {
    if (_on) return;
    _on = true;
    _send(_current);
    _beat = Timer.periodic(const Duration(seconds: 30), (_) => _ping(null));
    _life = AppLifecycleListener(
      onHide: () => _ping('offline'),
      onShow: () => _send(_current),
      onResume: () => _send(_current),
    );
  }

  static void stop() {
    if (!_on) return;
    _ping('offline');
    _beat?.cancel();
    _life?.dispose();
    _stack.clear();
    _on = false;
  }

  static (String, String?, String?) get _current =>
      _stack.isEmpty ? _base : _stack.last;

  static void base(String screen) {
    _base = (screen, null, null);
    if (_stack.isEmpty) _send(_base);
  }

  static void push(String screen, {String? storeId, String? product}) {
    _stack.add((screen, storeId, product));
    _send(_stack.last);
  }

  static void pop() {
    if (_stack.isNotEmpty) _stack.removeLast();
    _send(_current);
  }

  static void _send((String, String?, String?) t) {
    if (!_on) return;
    sb.rpc('track_customer', params: {
      'p_screen': t.$1,
      'p_store': t.$2,
      'p_product': t.$3,
    }).catchError((_) => null);
  }

  static void _ping(String? screen) {
    if (sb.auth.currentUser == null) return;
    sb.rpc('track_customer',
        params: {'p_screen': screen}).catchError((_) => null);
  }
}

/// Marks the page it wraps as the customer's current place while it is open.
class PresenceTag extends StatefulWidget {
  const PresenceTag(
      {super.key,
      required this.screen,
      this.storeId,
      this.product,
      required this.child});
  final String screen;
  final String? storeId, product;
  final Widget child;
  @override
  State<PresenceTag> createState() => _PresenceTagState();
}

class _PresenceTagState extends State<PresenceTag> {
  @override
  void initState() {
    super.initState();
    Presence.push(widget.screen,
        storeId: widget.storeId, product: widget.product);
  }

  @override
  void dispose() {
    Presence.pop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
