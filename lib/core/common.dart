import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ttext.dart';
import 'i18n.dart';

SupabaseClient get sb => Supabase.instance.client;
String? get myId => sb.auth.currentUser?.id;

/// Records a sign-in or sign-out in the activity log. Never throws.
Future<void> logEvent(String action) async {
  try {
    await sb.rpc('log_client_event', params: {'p_action': action});
  } catch (_) {}
}

final _money = NumberFormat('#,##0.000', 'en');
String bhd(dynamic v) =>
    '${_money.format(num.tryParse('${v ?? 0}') ?? 0)} ${tr('د.ب')}';
num toNum(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;
String dateText(dynamic v) {
  if (v == null) return '';
  final d = DateTime.tryParse('$v');
  return d == null ? '$v' : DateFormat('d/M/yyyy').format(d.toLocal());
}

String dateTimeText(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? '' : DateFormat('d/M/yyyy · h:mm a').format(d.toLocal());
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String normPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00973')) d = d.substring(5);
  if (d.startsWith('973') && d.length == 11) d = d.substring(3);
  return d;
}

const statusLabels = {
  'new': 'جديد',
  'accepted': 'مقبول',
  'slaughtering': 'قيد الذبح',
  'ready': 'جاهز للتوصيل',
  'out_for_delivery': 'في الطريق',
  'delivered': 'تم التسليم',
  'cancelled': 'ملغي',
};
const statusFlow = [
  'new',
  'accepted',
  'slaughtering',
  'ready',
  'out_for_delivery',
  'delivered'
];
const paymentLabels = {
  'benefitpay': 'BenefitPay',
  'bank_transfer': 'تحويل بنكي',
  'cash': 'نقداً عند الاستلام'
};

/// The payment method an order used: the admin's method name, else the built-in label.
String payLabel(Map o) =>
    '${o['payment_method_name'] ?? paymentLabels[o['payment_method']] ?? ''}';

/// Payment status, plus the card approval code once an online payment is accepted.
String payStatusText(Map o) {
  final s = tr(paymentStatusLabels[o['payment_status']] ?? '');
  final auth = o['payment_auth'];
  return o['payment_status'] == 'paid' && auth != null && '$auth'.isNotEmpty
      ? '$s · ${tr('رقم التفويض')} $auth'
      : s;
}

const paymentStatusLabels = {
  'pending': 'بانتظار الدفع',
  'awaiting_review': 'بانتظار مراجعة التحويل',
  'paid': 'مدفوع',
  'refunded': 'مسترجع'
};

/// Buy (with cutting options) or reserve (dates only); stored in the first item's options.
String orderKind(Map o) {
  final items = o['order_items'];
  if (items is List && items.isNotEmpty) {
    final opt = items.first['options'];
    if (opt is Map && opt['kind'] == 'reservation') return 'reservation';
  }
  return 'purchase';
}

const orderKindLabels = {'purchase': 'شراء', 'reservation': 'حجز'};
const planLabels = {'trial': 'تجريبية', 'monthly': 'شهرية', 'yearly': 'سنوية'};
const roleLabels = {
  'admin': 'الإدارة العامة',
  'merchant_owner': 'مالك متجر',
  'merchant_staff': 'موظف متجر',
  'driver': 'مندوب توصيل',
  'customer': 'عميل',
};
const merchantPermLabels = {
  'orders': 'استلام الطلبات وتحديث حالتها',
  'products': 'إدارة المنتجات',
  'pricing': 'تعديل الأسعار',
  'offers': 'إدارة العروض',
  'wallet': 'عرض المحفظة',
  'staff': 'إدارة الموظفين',
};

Color statusColor(String s) => switch (s) {
      'new' => const Color(0xFFD9822B),
      'accepted' => const Color(0xFF1F6FD1),
      'slaughtering' => const Color(0xFFB83250),
      'ready' => const Color(0xFF6A4BC4),
      'out_for_delivery' => const Color(0xFF0E8FA8),
      'delivered' => const Color(0xFF1E8A5F),
      _ => const Color(0xFF8A8F98),
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99)),
      child: Text(statusLabels[status] ?? status,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? const Color(0xFF8F1D13) : null,
  ));
}

String errText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) {
    if (e.message.contains('Invalid login'))
      return 'رقم الجوال أو كلمة المرور غير صحيحة';
    return e.message;
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return 'تعذّر تنفيذ الطلب';
  }
  return '$e';
}

/// Runs [fn], shows the error as a snackbar, returns null on failure.
Future<T?> guard<T>(BuildContext context, Future<T> Function() fn,
    {String? ok}) async {
  try {
    final r = await fn();
    if (ok != null && context.mounted) toast(context, ok);
    return r;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), error: true);
    return null;
  }
}

/// Calls the `users` edge function and throws its Arabic error text on failure.
Future<Map<String, dynamic>> usersFn(Map<String, dynamic> body) async {
  final r = await sb.functions.invoke('users', body: body);
  final data = r.data;
  if (data is Map && data['ok'] == true) return Map<String, dynamic>.from(data);
  throw Exception(data is Map ? data['error'] ?? 'خطأ' : 'خطأ');
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: Colors.black26),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ]),
        ),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key, this.title, required this.child, this.trailing});
  final String? title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Expanded(
                      child: Text(title!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700))),
                  if (trailing != null) trailing!,
                ]),
              ),
            child,
          ]),
        ),
      );
}

class KeyVal extends StatelessWidget {
  const KeyVal(this.k, this.v, {super.key, this.bold = false});
  final String k;
  final String v;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(k, style: const TextStyle(color: Colors.black54))),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
}

/// Reload-on-demand list loader with pull-to-refresh and realtime refresh.
class Loader<T> extends StatefulWidget {
  const Loader(
      {super.key,
      required this.load,
      required this.builder,
      this.realtimeTables = const [],
      this.refreshEvery});
  final Future<T> Function() load;

  /// Reload on a timer too (for data that changes with time, like driver turns).
  final Duration? refreshEvery;
  final Widget Function(
      BuildContext context, T data, Future<void> Function() reload) builder;
  final List<String> realtimeTables;
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? data;
  Object? error;
  RealtimeChannel? ch;
  Timer? tick;

  @override
  void initState() {
    super.initState();
    reload();
    if (widget.refreshEvery != null) {
      tick = Timer.periodic(widget.refreshEvery!, (_) => reload());
    }
    if (widget.realtimeTables.isNotEmpty) {
      var c = sb.channel('rt-${identityHashCode(this)}');
      for (final t in widget.realtimeTables) {
        c = c.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: t,
            callback: (_) => reload());
      }
      ch = c..subscribe();
    }
  }

  @override
  void dispose() {
    tick?.cancel();
    if (ch != null) sb.removeChannel(ch!);
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (mounted)
        setState(() {
          data = d;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(errText(error!), textAlign: TextAlign.center),
          TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
        ]),
      );
    }
    if (data == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
        onRefresh: reload, child: widget.builder(context, data as T, reload));
  }
}

class Field extends StatelessWidget {
  const Field(this.label, this.ctrl,
      {super.key,
      this.required = false,
      this.hint,
      this.keyboard,
      this.obscure = false,
      this.maxLines = 1,
      this.note,
      this.ltr = false});
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final String? hint;
  final String? note;
  final TextInputType? keyboard;
  final bool obscure;
  final int maxLines;
  final bool ltr;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: tr(required ? '$label *' : label),
          hintText: tr(hint),
          helperText: tr(note),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? tr('هذا الحقل مطلوب') : null
            : null,
      );
}

/// A storage-safe file name. Supabase Storage rejects keys with Arabic letters or
/// spaces, so keep only ASCII letters, digits, dot, dash and underscore, and
/// always keep a unique stamp plus the original extension.
String safeFileName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0
      ? ''
      : name
          .substring(dot + 1)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
  final base = (dot < 0 ? name : name.substring(0, dot))
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final b =
      base.isEmpty ? 'file' : (base.length > 40 ? base.substring(0, 40) : base);
  return ext.isEmpty ? '$stamp-$b' : '$stamp-$b.$ext';
}

/// Content type for an uploaded file, from its extension.
String mimeOf(String name) {
  final e = name.split('.').last.toLowerCase();
  return switch (e) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

/// "12:05" or "1:02:05".
String durationText(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, sec = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// A live stopwatch from [start] (stops at [end] when given).
class ElapsedTimer extends StatefulWidget {
  const ElapsedTimer(this.start, {super.key, this.end, this.style});
  final dynamic start;
  final dynamic end;
  final TextStyle? style;
  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  Timer? t;
  @override
  void initState() {
    super.initState();
    if (widget.end == null) {
      t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = DateTime.tryParse('${widget.start}')?.toLocal();
    if (s == null) return const SizedBox.shrink();
    final e = DateTime.tryParse('${widget.end}')?.toLocal() ?? DateTime.now();
    return Text(durationText(e.difference(s)),
        textDirection: TextDirection.ltr,
        style: widget.style ??
            const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()]));
  }
}

/// Status label for an order; pickup orders read "ready for pickup".
String statusOf(Map o) => o['fulfillment'] == 'pickup' && o['status'] == 'ready'
    ? 'جاهز للاستلام'
    : statusLabels[o['status']] ?? '${o['status']}';
