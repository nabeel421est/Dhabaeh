import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/common.dart';
import '../core/i18n.dart';
import '../core/page_nav_stub.dart'
    if (dart.library.js_interop) '../core/page_nav_web.dart';
import '../core/ttext.dart';
import 'admin_ui.dart';

/// التحكم الإداري → الدومين: the app's web address on GitHub Pages, DNS checks,
/// attaching / detaching a custom domain, HTTPS and redeploys (edge function `site`).
class AdminDomain extends StatefulWidget {
  const AdminDomain({super.key});
  @override
  State<AdminDomain> createState() => _AdminDomainState();
}

const _ok = Color(0xFF12805C),
    _bad = Color(0xFFB3261E),
    _wait = Color(0xFFB7791F);

class _AdminDomainState extends State<AdminDomain> {
  Map<String, dynamic>? st;
  Object? err;
  Map<String, dynamic>? dns;
  bool busy = false;
  final input = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await edgeFn('site', {'action': 'status'});
      if (!mounted) return;
      setState(() {
        st = r;
        err = null;
        if (r['dns'] is Map) dns = Map<String, dynamic>.from(r['dns']);
        if (input.text.isEmpty && r['cname'] != null) {
          input.text = '${r['cname']}';
        }
      });
    } catch (e) {
      if (mounted) setState(() => err = e);
    }
  }

  Future<void> run(String action,
      [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    final r = await guard(
        context, () => edgeFn('site', {'action': action, ...extra}));
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    if (action == 'check') {
      setState(() => dns = r);
    } else {
      toast(context, tr('تم'));
      await load();
    }
  }

  String get typed => input.text.trim().toLowerCase();

  Future<void> attach() async {
    if (dns == null || dns!['domain'] != typed) {
      await run('check', {'domain': typed});
      if (!mounted || dns == null) return;
    }
    final ready = dns?['ok'] == true;
    final sure = await askSure(
        context,
        tr('ربط الدومين'),
        '${tr('سيصبح عنوان التطبيق')} https://$typed/\n\n'
        '${ready ? '' : '${tr('تنبيه: سجلات DNS لا تشير إلى GitHub بعد، فلن يفتح الموقع حتى تُضبط.')}\n\n'}'
        '${tr('بعد النشر (دقيقتان تقريباً) يفتح المستخدمون العنوان الجديد، ومن ثبّت التطبيق على الشاشة الرئيسية يعيد تثبيته ويفعّل الإشعارات من جديد. العنوان القديم يحوّل تلقائياً للجديد.')}',
        yes: tr('ربط'));
    if (sure) await run('attach', {'domain': typed});
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    if (s == null) {
      if (err != null) {
        return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(errText(err!), textAlign: TextAlign.center),
          TextButton(onPressed: load, child: const Text('إعادة المحاولة')),
        ]));
      }
      return const Center(child: CircularProgressIndicator());
    }
    final gh = s['github'] == true;
    final cname = s['cname'] as String?;
    final url = '${s['url'] ?? s['default_url']}';
    final last = s['run'] is Map ? Map<String, dynamic>.from(s['run']) : null;
    final cert = s['https_certificate'] as String?;
    final https = s['https_enforced'] == true;
    return RefreshIndicator(
      onRefresh: load,
      child: LuxPage(children: [
        LuxHero(
          title: tr('الدومين وعنوان التطبيق'),
          line: tr('اربط اسم نطاق خاص بالمنصة وتابع حالة النشر والأمان'),
          stats: [
            (
              Icons.link_rounded,
              tr('العنوان الحالي'),
              Uri.tryParse(url)?.host ?? url
            ),
            (
              Icons.verified_user_outlined,
              'HTTPS',
              https ? tr('مفعّل') : tr('غير مفعّل')
            ),
            (Icons.rocket_launch_outlined, tr('آخر نشر'), _runText(last)),
          ],
          actions: [
            LuxButton(Icons.open_in_new_rounded, tr('فتح الموقع'),
                () => pageOpen(url)),
            LuxButton(Icons.copy_rounded, tr('نسخ الرابط'), () {
              Clipboard.setData(ClipboardData(text: url));
              toast(context, tr('تم النسخ'));
            }, filled: false),
            LuxButton(Icons.refresh_rounded, tr('إعادة النشر'),
                gh && !busy ? () => run('redeploy') : null,
                filled: false),
          ],
        ),
        if (!gh) _tokenNote(),
        LuxCard(
          icon: Icons.dns_outlined,
          title: tr('حالة الموقع'),
          trailing: IconButton(
              tooltip: tr('تحديث'),
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded)),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            LuxPill(gh ? tr('GitHub مربوط') : tr('GitHub غير مربوط'),
                gh ? _ok : _bad,
                icon: gh ? Icons.check_circle : Icons.link_off),
            LuxPill(
                cname == null
                    ? tr('العنوان الافتراضي')
                    : '${tr('دومين خاص')}: $cname',
                cname == null ? const Color(0xFF475569) : _ok,
                icon: Icons.language),
            if (cname != null)
              LuxPill('${tr('الشهادة')}: ${_certText(cert)}',
                  cert == 'approved' ? _ok : _wait,
                  icon: Icons.workspace_premium_outlined),
            LuxPill(https ? tr('HTTPS إلزامي') : tr('HTTPS غير إلزامي'),
                https ? _ok : _wait,
                icon: Icons.lock_outline),
            if (last != null)
              LuxPill(
                  '${tr('آخر نشر')}: ${_runText(last)}',
                  last['conclusion'] == 'success'
                      ? _ok
                      : last['status'] == 'completed'
                          ? _bad
                          : _wait,
                  icon: Icons.rocket_launch_outlined),
          ]),
        ),
        LuxCard(
          icon: Icons.travel_explore_rounded,
          title: cname == null ? tr('ربط دومين خاص') : tr('الدومين المربوط'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (cname == null)
              const Text(
                  'اكتب الدومين الذي اشتريته (مثل dhabaeh.com)، ثم افحص السجلات، وبعد أن تظهر كلها صحيحة اضغط ربط.',
                  style: TextStyle(color: Colors.black54, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  enabled: cname == null,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'dhabaeh.com',
                    prefixIcon: const Icon(Icons.public),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (_) => run('check', {'domain': typed}),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => run('check', {'domain': typed}),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('فحص'),
              ),
            ]),
            if (dns != null) ...[
              const SizedBox(height: 16),
              _DnsTable(dns!),
            ],
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 6),
            if (cname == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: !gh || busy || typed.isEmpty ? null : attach,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('ربط الدومين'),
                ),
              )
            else
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.tonalIcon(
                  onPressed:
                      !gh || busy ? null : () => run('https', {'on': !https}),
                  icon: Icon(https ? Icons.lock_open : Icons.lock),
                  label:
                      Text(https ? tr('إلغاء إلزام HTTPS') : tr('إلزام HTTPS')),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _bad),
                  onPressed: !gh || busy
                      ? null
                      : () async {
                          final ok = await askSure(context, tr('فصل الدومين'),
                              tr('سيرجع التطبيق إلى العنوان الافتراضي على GitHub، ومن ثبّته بالعنوان الحالي يحتاج يعيد تثبيته.'),
                              yes: tr('فصل'), danger: true);
                          if (ok) await run('detach');
                        },
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('فصل الدومين'),
                ),
              ]),
            if (cname != null && cert != 'approved')
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'شهادة الأمان تصدر تلقائياً من GitHub خلال دقائق إلى 24 ساعة بعد ضبط السجلات. بعدها فعّل «إلزام HTTPS».',
                    style: TextStyle(color: Colors.black54, height: 1.5)),
              ),
          ]),
        ),
        LuxCard(
          icon: Icons.menu_book_outlined,
          title: tr('طريقة الضبط عند مزوّد الدومين'),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step('1',
                    'ادخل لوحة الشركة التي اشتريت منها الدومين (GoDaddy أو Namecheap أو غيرها) وافتح إعدادات DNS.'),
                _Step('2',
                    'للدومين الرئيسي: أضف أربع سجلات A تشير إلى عناوين GitHub الظاهرة في جدول الفحص، وسجل CNAME باسم www يشير إلى nabeel421est.github.io.'),
                _Step('3',
                    'لدومين فرعي (مثل app.dhabaeh.com): أضف سجل CNAME واحد باسمه يشير إلى nabeel421est.github.io.'),
                _Step('4',
                    'احذف أي سجلات A أو CNAME قديمة لنفس الاسم، ثم ارجع هنا واضغط فحص. انتشار السجلات قد يأخذ من دقائق إلى ساعات.'),
                _Step('5',
                    'عندما تظهر كل السجلات صحيحة اضغط ربط الدومين، ثم فعّل إلزام HTTPS بعد صدور الشهادة.'),
              ]),
        ),
      ]),
    );
  }

  Widget _tokenNote() => LuxCard(
        icon: Icons.key_outlined,
        title: tr('اربط مفتاح GitHub أولاً'),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'الفحص يعمل الآن، لكن ربط الدومين وإعادة النشر يحتاجان مفتاح GitHub باسم GH_TOKEN في أسرار Supabase.',
                  style: TextStyle(height: 1.5)),
              SizedBox(height: 10),
              _Step('1',
                  'في GitHub: Settings ← Developer settings ← Fine-grained tokens ← Generate new token.'),
              _Step('2',
                  'اختر المستودع nabeel421est/Dhabaeh فقط، وأعط صلاحيات Pages و Variables و Actions: Read and write.'),
              _Step('3',
                  'في Supabase: Edge Functions ← Secrets ← Add new secret، الاسم GH_TOKEN والقيمة المفتاح.'),
            ]),
      );

  String _runText(Map<String, dynamic>? r) {
    if (r == null) return '—';
    final when = r['at'] == null ? '' : ' · ${dateTimeText(r['at'])}';
    if (r['status'] != 'completed') return '${tr('جارٍ')}$when';
    return '${r['conclusion'] == 'success' ? tr('ناجح') : tr('فشل')}$when';
  }

  String _certText(String? c) => switch (c) {
        'approved' => tr('صادرة'),
        null => tr('لم تصدر بعد'),
        _ => tr('قيد الإصدار'),
      };
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final String n, text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF1A4C8C),
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ]),
      );
}

/// Expected records vs what the domain points to now.
class _DnsTable extends StatelessWidget {
  const _DnsTable(this.d);
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context) {
    final a = [for (final x in (d['a'] as List? ?? [])) '$x'];
    final cn = [
      for (final x in (d['cname'] as List? ?? [])) '$x'.toLowerCase()
    ];
    final ok = d['ok'] == true;
    final rows = [
      for (final e in (d['expected'] as List? ?? []))
        Map<String, dynamic>.from(e)
    ];
    bool rowOk(Map<String, dynamic> e) {
      if (e['type'] == 'A') return a.contains(e['value']);
      if (e['host'] == 'www') return d['www_ok'] == true;
      return cn.contains('${e['value']}'.toLowerCase()) || ok;
    }

    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          color: const Color(0xFFF8FAFD)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('${d['domain']}',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          LuxPill(ok ? tr('السجلات صحيحة') : tr('السجلات غير مكتملة'),
              ok ? _ok : _bad,
              icon: ok ? Icons.verified : Icons.error_outline),
        ]),
        const SizedBox(height: 10),
        const Text('السجلات المطلوبة',
            style: TextStyle(color: Colors.black54, fontSize: 12.5)),
        const SizedBox(height: 6),
        for (final e in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(rowOk(e) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: rowOk(e) ? _ok : Colors.black38),
              const SizedBox(width: 8),
              SizedBox(
                  width: 58,
                  child: Text('${e['type']}',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(
                  width: 60,
                  child:
                      Text('${e['host']}', textDirection: TextDirection.ltr)),
              Expanded(
                child: SelectableText('${e['value']}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'monospace')),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr('نسخ'),
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: '${e['value']}')),
              ),
            ]),
          ),
        const Divider(height: 20),
        Text(
            '${tr('يشير الآن إلى')}: ${[
              ...a,
              ...cn
            ].isEmpty ? tr('لا توجد سجلات') : [...cn, ...a].join('، ')}',
            style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
      ]),
    );
  }
}
