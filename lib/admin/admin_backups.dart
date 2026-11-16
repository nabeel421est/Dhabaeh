import 'package:flutter/material.dart' hide Text;

import '../core/common.dart';
import '../core/i18n.dart';
import '../core/page_nav_stub.dart'
    if (dart.library.js_interop) '../core/page_nav_web.dart';
import '../core/ttext.dart';
import 'admin_ui.dart';

/// التحكم الإداري → النسخ الاحتياطية: full database exports (edge function `backup`)
/// kept in the private «backups» bucket, made daily at 3:00 AM and on demand.
class AdminBackups extends StatefulWidget {
  const AdminBackups({super.key});
  @override
  State<AdminBackups> createState() => _AdminBackupsState();
}

class _AdminBackupsState extends State<AdminBackups> {
  bool busy = false;

  Future<(List<Map<String, dynamic>>, Map<String, dynamic>)> load() async {
    final rows = await sb
        .from('backup_log')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    final s = await sb
        .from('platform_settings')
        .select('backup_auto, backup_keep')
        .eq('id', 1)
        .maybeSingle();
    return (
      [for (final r in rows) Map<String, dynamic>.from(r)],
      Map<String, dynamic>.from(s ?? {})
    );
  }

  Future<void> makeNow(Future<void> Function() reload) async {
    setState(() => busy = true);
    final r = await guard(context, () => edgeFn('backup', {'action': 'create'}),
        ok: tr('تم إنشاء النسخة الاحتياطية'));
    if (mounted) setState(() => busy = false);
    if (r != null) await reload();
  }

  Future<void> download(Map b) async {
    final r = await guard(
        context, () => edgeFn('backup', {'action': 'link', 'id': b['id']}));
    final url = r?['url'];
    if (url is String) pageOpen(url);
  }

  Future<void> remove(Map b, Future<void> Function() reload) async {
    final ok = await askSure(context, tr('حذف النسخة'),
        '${tr('ستُحذف هذه النسخة نهائياً')}: ${dateTimeText(b['created_at'])}',
        yes: tr('حذف'), danger: true);
    if (!ok || !mounted) return;
    final r = await guard(
        context, () => edgeFn('backup', {'action': 'remove', 'id': b['id']}),
        ok: tr('تم الحذف'));
    if (r != null) await reload();
  }

  Future<void> save(
      Map<String, dynamic> v, Future<void> Function() reload) async {
    await guard(
        context, () => sb.from('platform_settings').update(v).eq('id', 1),
        ok: tr('تم الحفظ'));
    await reload();
  }

  @override
  Widget build(BuildContext context) =>
      Loader<(List<Map<String, dynamic>>, Map<String, dynamic>)>(
        load: load,
        realtimeTables: const ['backup_log'],
        builder: (context, d, reload) {
          final (list, s) = d;
          final auto = s['backup_auto'] != false;
          final keep = (s['backup_keep'] as num?)?.toInt() ?? 14;
          final size =
              list.fold<num>(0, (a, b) => a + ((b['size_bytes'] as num?) ?? 0));
          final last = list.isEmpty ? null : list.first;
          return LuxPage(children: [
            LuxHero(
              title: tr('النسخ الاحتياطية'),
              line: tr(
                  'نسخة كاملة من بيانات المنصة، محفوظة بأمان ويمكن تنزيلها في أي وقت'),
              stats: [
                (Icons.inventory_2_outlined, tr('عدد النسخ'), '${list.length}'),
                (
                  Icons.schedule_rounded,
                  tr('آخر نسخة'),
                  last == null ? '—' : dateTimeText(last['created_at'])
                ),
                (Icons.sd_storage_outlined, tr('الحجم الكلي'), _size(size)),
                (
                  Icons.autorenew_rounded,
                  tr('النسخ التلقائي'),
                  auto ? tr('يومياً 3:00 ص') : tr('متوقف')
                ),
              ],
              actions: [
                LuxButton(
                    Icons.cloud_upload_outlined,
                    busy ? tr('جارٍ الإنشاء…') : tr('إنشاء نسخة الآن'),
                    busy ? null : () => makeNow(reload)),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            LuxCard(
              icon: Icons.tune_rounded,
              title: tr('الإعدادات'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: auto,
                      onChanged: (v) => save({'backup_auto': v}, reload),
                      title: const Text('نسخة تلقائية كل يوم'),
                      subtitle: const Text('الساعة 3:00 فجراً بتوقيت البحرين'),
                    ),
                    const Divider(),
                    Row(children: [
                      const Expanded(
                        child: Text('الاحتفاظ بآخر النسخ التلقائية',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      DropdownButton<int>(
                        value: const [7, 14, 30, 60].contains(keep) ? keep : 14,
                        items: [
                          for (final n in const [7, 14, 30, 60])
                            DropdownMenuItem(
                                value: n, child: Text('$n ${tr('نسخة')}')),
                        ],
                        onChanged: (v) =>
                            v == null ? null : save({'backup_keep': v}, reload),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                        'الأقدم من ذلك يُحذف تلقائياً. النسخ اليدوية تبقى حتى تحذفها بنفسك. كل نسخة تشمل جميع الجداول: الطلبات والحسابات والمحافظ والمنتجات والإعدادات.',
                        style: TextStyle(
                            color: Colors.black54,
                            height: 1.5,
                            fontSize: 12.5)),
                  ]),
            ),
            LuxCard(
              icon: Icons.history_rounded,
              title: tr('سجل النسخ'),
              child: list.isEmpty
                  ? const Empty('لا توجد نسخ بعد',
                      icon: Icons.cloud_off_outlined)
                  : Column(children: [
                      for (final b in list)
                        _BackupTile(
                          b: b,
                          onDownload: () => download(b),
                          onRemove: () => remove(b, reload),
                        ),
                    ]),
            ),
          ]);
        },
      );
}

String _size(num b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(2)} MB';
}

class _BackupTile extends StatelessWidget {
  const _BackupTile(
      {required this.b, required this.onDownload, required this.onRemove});
  final Map<String, dynamic> b;
  final VoidCallback onDownload, onRemove;
  @override
  Widget build(BuildContext context) {
    final auto = b['kind'] == 'auto';
    final c = auto ? const Color(0xFF0F6A5C) : const Color(0xFF6B4BC4);
    final summary = b['summary'] is Map
        ? Map<String, dynamic>.from(b['summary'])
        : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF8FBFA),
        border: Border.all(color: c.withValues(alpha: .18)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                    colors: [c, Color.lerp(c, Colors.white, .4)!])),
            child: Icon(
                auto ? Icons.autorenew_rounded : Icons.back_hand_outlined,
                color: Colors.white,
                size: 20),
          ),
          title: Text(dateTimeText(b['created_at']),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              LuxPill(auto ? tr('تلقائية') : tr('يدوية'), c),
              LuxPill(_size((b['size_bytes'] as num?) ?? 0),
                  const Color(0xFF475569)),
              LuxPill(
                  '${b['tables'] ?? 0} ${tr('جدول')} · ${b['total_rows'] ?? 0} ${tr('سجل')}',
                  const Color(0xFF475569)),
            ]),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: tr('تنزيل'),
                onPressed: onDownload,
                icon: Icon(Icons.download_rounded, color: c)),
            IconButton(
                tooltip: tr('حذف'),
                onPressed: onRemove,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFB3261E))),
          ]),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in summary.entries)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${e.key}: ${e.value}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5)),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
