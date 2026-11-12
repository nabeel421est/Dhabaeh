import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import 'alert_bridge_stub.dart'
    if (dart.library.js_interop) 'alert_bridge_web.dart';
import 'common.dart';
import 'ttext.dart';

/// True once this device receives push notifications for the signed-in user.
final pushOn = ValueNotifier<bool>(false);

Future<void> _save(String json) async {
  final m = jsonDecode(json) as Map<String, dynamic>;
  final keys = Map<String, dynamic>.from(m['keys'] ?? {});
  await sb.rpc('push_register', params: {
    'p_endpoint': m['endpoint'],
    'p_p256dh': keys['p256dh'],
    'p_auth': keys['auth'],
    'p_ua': null,
  });
}

/// After sign-in: if this device is already subscribed, attach it to this user.
Future<String> pushRefresh() async {
  final st = await pushStatus();
  if (st == 'subscribed') {
    final cur = await pushCurrent();
    if (cur.isNotEmpty) {
      try {
        await _save(cur);
        pushOn.value = true;
      } catch (_) {}
    }
  }
  return st;
}

/// Before sign-out: stop sending this user's pushes to this device.
Future<void> pushSignOut() async {
  try {
    final cur = await pushCurrent();
    if (cur.isEmpty) return;
    final m = jsonDecode(cur) as Map<String, dynamic>;
    await sb.rpc('push_unregister', params: {'p_endpoint': m['endpoint']});
  } catch (_) {}
  pushOn.value = false;
}

/// A slim bar asking to turn on push notifications on this device. Hidden once
/// on, or when the browser can't do push.
class PushBanner extends StatefulWidget {
  const PushBanner({super.key});
  @override
  State<PushBanner> createState() => _PushBannerState();
}

class _PushBannerState extends State<PushBanner> {
  String status = 'loading';
  String? key;
  bool busy = false;
  bool hidden = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final st = await pushRefresh();
    if (st == 'default' || st == 'granted') {
      try {
        key = await sb.rpc('push_public_key') as String?;
      } catch (_) {}
    }
    if (mounted) setState(() => status = st);
  }

  Future<void> _turnOn() async {
    if (key == null) return;
    setState(() => busy = true);
    // Straight from the tap so the phone shows its permission prompt.
    final r = await pushSubscribe(key!);
    if (!mounted) return;
    if (r.startsWith('error:')) {
      setState(() {
        busy = false;
        status = r.contains('denied') ? 'denied' : status;
      });
      toast(
          context,
          r.contains('denied')
              ? 'رفضت الإشعارات. فعّلها من إعدادات الهاتف ← الإشعارات ← ذبائح'
              : 'تعذر تفعيل الإشعارات على هذا الجهاز',
          error: true);
      return;
    }
    try {
      await _save(r);
      pushOn.value = true;
      if (mounted) {
        setState(() {
          busy = false;
          status = 'subscribed';
        });
        toast(context, 'تم تفعيل الإشعارات الفورية على هذا الجهاز');
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, errText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox.shrink();
    final ask = status == 'default' || status == 'granted';
    final ios = status == 'ios-browser';
    final denied = status == 'denied';
    if (!ask && !ios && !denied) return const SizedBox.shrink();
    final text = ios
        ? 'لتصلك الإشعارات على شاشة الهاتف: أضف التطبيق للشاشة الرئيسية وافتحه من أيقونته'
        : denied
            ? 'الإشعارات مقفلة لهذا التطبيق. فعّلها من إعدادات الهاتف ← الإشعارات'
            : 'فعّل الإشعارات الفورية لتصلك الطلبات على شاشة الهاتف حتى والتطبيق مقفل';
    return Material(
      color: const Color(0xFFFFF4D6),
      child: InkWell(
        onTap: ask && !busy ? _turnOn : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(children: [
            const Icon(Icons.notifications_active_outlined,
                color: Color(0xFF9A6A00)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Color(0xFF6B4A00),
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
            if (ask)
              busy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('تفعيل',
                          style: TextStyle(
                              color: Color(0xFF9A6A00),
                              fontWeight: FontWeight.w800)),
                    ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF9A6A00)),
              onPressed: () => setState(() => hidden = true),
            ),
          ]),
        ),
      ),
    );
  }
}
