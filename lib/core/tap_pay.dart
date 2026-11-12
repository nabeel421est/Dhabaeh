import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'common.dart';
import 'i18n.dart';
import 'page_nav_stub.dart' if (dart.library.js_interop) 'page_nav_web.dart';
import 'ttext.dart';

/// Calls the «tap» edge function and throws its Arabic error on failure.
Future<Map<String, dynamic>> tapFn(Map<String, dynamic> body) async {
  try {
    final r = await sb.functions.invoke('tap', body: body);
    final d = r.data;
    if (d is Map && d['error'] == null) return Map<String, dynamic>.from(d);
    throw Exception(d is Map ? d['error'] : 'خطأ');
  } on FunctionException catch (e) {
    final d = e.details;
    throw Exception(d is Map ? d['error'] ?? 'خطأ' : 'خطأ');
  }
}

/// Is the method with [code] paid online through the Tap page?
Future<bool> isTapMethod(String? code) async {
  if (code == null) return false;
  final m = await sb
      .from('payment_methods')
      .select('gateway')
      .eq('code', code)
      .maybeSingle();
  return m?['gateway'] == 'tap';
}

/// Sends the customer to Tap's payment page (Apple Pay, cards) for [orderId].
/// Tap brings them back to the app with ?tap_id=…, handled by [checkTapReturn].
Future<bool> startTapPay(BuildContext context, String orderId) async {
  final back = Uri.base
      .replace(queryParameters: {'tap_order': orderId}, fragment: '')
      .toString()
      .replaceAll('#', '');
  final r = await guard(
      context,
      () =>
          tapFn({'action': 'create', 'order_id': orderId, 'return_url': back}));
  final url = r?['url'];
  if (url is String && url.startsWith('https://')) {
    pageGo(url);
    return true;
  }
  return false;
}

/// Back from Tap: confirm the payment and tell the customer.
/// Returns the order id to open, or null when the app was not opened from Tap.
Future<String?> checkTapReturn(BuildContext context) async {
  final q = Uri.base.queryParameters;
  final charge = q['tap_id'];
  final order = q['tap_order'];
  if (charge == null && order == null) return null;
  pageCleanQuery();
  if (charge == null) return order;
  final r = await guard(
      context, () => tapFn({'action': 'verify', 'charge_id': charge}));
  if (r != null && context.mounted) {
    r['paid'] == true
        ? toast(context, 'تم الدفع بنجاح، شكراً لك')
        : toast(context, 'لم تكتمل عملية الدفع، تقدر تعيد المحاولة من الطلب',
            error: true);
  }
  return (r?['order_id'] as String?) ?? order;
}

/// «ادفع الآن» on an unpaid order whose method goes through Tap.
class TapPayButton extends StatefulWidget {
  const TapPayButton({super.key, required this.order});
  final Map<String, dynamic> order;
  @override
  State<TapPayButton> createState() => _TapPayButtonState();
}

class _TapPayButtonState extends State<TapPayButton> {
  late final Future<bool> tapMethod =
      isTapMethod(widget.order['payment_method_code'] as String?);
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (o['payment_status'] == 'paid' ||
        o['status'] == 'cancelled' ||
        o['customer_id'] != myId) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<bool>(
      future: tapMethod,
      builder: (_, s) => s.data != true
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final ok = await startTapPay(context, o['id']);
                        if (!ok && mounted) setState(() => busy = false);
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.apple, color: Colors.white),
                label: Text('${tr('ادفع الآن')} · ${bhd(o['total'])}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
    );
  }
}
