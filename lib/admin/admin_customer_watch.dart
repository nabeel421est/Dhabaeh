import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/common.dart';
import '../core/i18n.dart';
import '../core/page_nav_stub.dart'
    if (dart.library.js_interop) '../core/page_nav_web.dart';
import '../core/ttext.dart';
import 'admin_ui.dart';

const _on = Color(0xFF12B76A), _onDark = Color(0xFF05603A);
const _off = Color(0xFFE5484D), _offDark = Color(0xFF8A1C24);

String _ago(dynamic at) {
  if (at == null) return tr('لم يدخل بعد');
  final t = DateTime.tryParse('$at')?.toLocal();
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return tr('الآن');
  if (d.inMinutes < 60) return '${tr('منذ')} ${d.inMinutes} ${tr('دقيقة')}';
  if (d.inHours < 24) return '${tr('منذ')} ${d.inHours} ${tr('ساعة')}';
  if (d.inDays < 30) return '${tr('منذ')} ${d.inDays} ${tr('يوم')}';
  return dateText(at);
}

String _place(Map c) => [
      if ((c['screen'] ?? '').toString().isNotEmpty) '${c['screen']}',
      if ((c['store_name'] ?? '').toString().isNotEmpty) '${c['store_name']}',
      if ((c['product_name'] ?? '').toString().isNotEmpty)
        '${c['product_name']}',
    ].join(' · ');

/// «مراقبة وتتبع العملاء»: who is in the customer app right now (green), who is
/// not (red), and where each customer went (screens, stores and products).
class AdminCustomerWatch extends StatefulWidget {
  const AdminCustomerWatch({super.key});
  @override
  State<AdminCustomerWatch> createState() => _AdminCustomerWatchState();
}

class _AdminCustomerWatchState extends State<AdminCustomerWatch> {
  String filter = 'all';
  String q = '';

  Future<List<Map<String, dynamic>>> load() async {
    final r = await sb.rpc('admin_customer_presence');
    return [for (final x in r as List) Map<String, dynamic>.from(x)];
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: load,
        realtimeTables: const ['customer_presence'],
        refreshEvery: const Duration(seconds: 20),
        builder: (context, all, reload) {
          final online = all.where((c) => c['online'] == true).length;
          final visits = all.fold<int>(
              0, (a, c) => a + ((c['visits_today'] as int?) ?? 0));
          final shown = all.where((c) {
            if (filter == 'on' && c['online'] != true) return false;
            if (filter == 'off' && c['online'] == true) return false;
            if (q.isEmpty) return true;
            return '${c['full_name']} ${c['phone']} ${c['area'] ?? ''} ${c['store_name'] ?? ''}'
                .contains(q);
          }).toList();
          return LuxPage(children: [
            LuxHero(
              title: tr('مراقبة وتتبع العملاء'),
              line: tr('من في تطبيق العملاء الآن، وأين يتصفح، وأي ملحمة اختار'),
              stats: [
                (Icons.circle, tr('متصل الآن'), '$online'),
                (
                  Icons.circle_outlined,
                  tr('غير متصل'),
                  '${all.length - online}'
                ),
                (Icons.route_outlined, tr('تنقلات اليوم'), '$visits'),
                (Icons.people_outline, tr('كل العملاء'), '${all.length}'),
              ],
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Filter(
                  tr('الكل'),
                  all.length,
                  const [Color(0xFF334155), Color(0xFF64748B)],
                  filter == 'all',
                  () => setState(() => filter = 'all')),
              _Filter(tr('المتصلون'), online, const [_onDark, _on],
                  filter == 'on', () => setState(() => filter = 'on'),
                  dot: _on),
              _Filter(
                  tr('غير المتصلين'),
                  all.length - online,
                  const [_offDark, _off],
                  filter == 'off',
                  () => setState(() => filter = 'off'),
                  dot: _off),
            ]),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('ابحث بالاسم أو الهاتف أو المنطقة أو الملحمة'),
              ),
              onChanged: (v) => setState(() => q = v.trim()),
            ),
            if (shown.isEmpty)
              const Empty('لا يوجد عملاء هنا', icon: Icons.people_outline)
            else
              LayoutBuilder(builder: (context, c) {
                final cols = (c.maxWidth / 330).floor().clamp(1, 4);
                final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final x in shown)
                    SizedBox(
                        width: w,
                        child: _CustomerCard(
                            c: x, onTap: () => _openCustomer(context, x))),
                ]);
              }),
          ]);
        },
      );
}

class _Filter extends StatelessWidget {
  const _Filter(this.label, this.count, this.colors, this.selected, this.onTap,
      {this.dot});
  final String label;
  final int count;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : Colors.white,
            border: Border.all(color: colors.last.withValues(alpha: .5)),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: colors.last.withValues(alpha: .4),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot != null) ...[
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : dot,
                      boxShadow: [
                        BoxShadow(
                            color: dot!.withValues(alpha: .6), blurRadius: 6)
                      ])),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.first)),
            const SizedBox(width: 8),
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : colors.last)),
          ]),
        ),
      );
}

/// Glowing status dot; pulses while the customer is online.
class _Dot extends StatefulWidget {
  const _Dot(this.online, {this.size = 14});
  final bool online;
  final double size;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  @override
  void initState() {
    super.initState();
    if (widget.online) a.repeat();
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.online ? _on : _off;
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.online)
            Container(
              width: widget.size * (1 + 1.2 * a.value),
              height: widget.size * (1 + 1.2 * a.value),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withValues(alpha: .45 * (1 - a.value))),
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: .7), blurRadius: 8)
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.c, {this.size = 50});
  final Map c;
  final double size;
  @override
  Widget build(BuildContext context) {
    final on = c['online'] == true;
    final name = '${c['full_name'] ?? ''}'.trim();
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: on
                  ? const [_on, Color(0xFF7CF0B8)]
                  : const [_off, Color(0xFFFF9A9E)]),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: on
                    ? const [Color(0xFF064E3B), Color(0xFF0E9F6E)]
                    : const [Color(0xFF5B1219), Color(0xFFB4323A)]),
          ),
          child: Text(name.isEmpty ? '؟' : name.characters.first,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .4,
                  fontWeight: FontWeight.w800)),
        ),
      ),
      PositionedDirectional(
          end: -size * .16,
          bottom: -size * .16,
          child: _Dot(on, size: size * .24)),
    ]);
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.c, required this.onTap});
  final Map<String, dynamic> c;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final on = c['online'] == true;
    final col = on ? _on : _off;
    final place = _place(c);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Colors.white,
                  Color.lerp(col, Colors.white, .86)!,
                ]),
            border: Border.all(
                color: col.withValues(alpha: on ? .55 : .3),
                width: on ? 1.6 : 1),
            boxShadow: [
              BoxShadow(
                  color: col.withValues(alpha: on ? .28 : .10),
                  blurRadius: on ? 22 : 12,
                  offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _Avatar(c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['full_name'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Text('${c['phone'] ?? ''}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12.5)),
                    ]),
              ),
              LuxPill(on ? tr('متصل') : tr('غير متصل'), on ? _onDark : _offDark,
                  icon: on ? Icons.wifi_tethering : Icons.wifi_off_rounded),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: .75),
                border: Border.all(color: col.withValues(alpha: .18)),
              ),
              child: Row(children: [
                Icon(on ? Icons.place_rounded : Icons.history_rounded,
                    size: 18, color: on ? _onDark : _offDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      on
                          ? (place.isEmpty ? tr('داخل التطبيق') : place)
                          : '${tr('آخر ظهور')}: ${_ago(c['last_seen'])}${place.isEmpty ? '' : ' · $place'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? _onDark : Colors.black87)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.route_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 4),
              Text('${c['visits_today'] ?? 0} ${tr('تنقل اليوم')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(width: 12),
              Icon(Icons.receipt_long_outlined,
                  size: 15, color: Colors.black45),
              const SizedBox(width: 4),
              Text('${c['orders_count'] ?? 0} ${tr('طلب')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const Spacer(),
              if ((c['area'] ?? '').toString().isNotEmpty)
                Text('${c['area']}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> _openCustomer(BuildContext context, Map<String, dynamic> c) =>
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: _CustomerSheet(c),
        ),
      ),
    );

class _CustomerSheet extends StatelessWidget {
  const _CustomerSheet(this.c);
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final on = c['online'] == true;
    final phone = '${c['phone'] ?? ''}';
    final place = _place(c);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: on
                  ? const [
                      Color(0xFF022C22),
                      Color(0xFF05603A),
                      Color(0xFF12B76A)
                    ]
                  : const [
                      Color(0xFF3B0A0F),
                      Color(0xFF8A1C24),
                      Color(0xFFE5484D)
                    ]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(c, size: 62),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c['full_name'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        on
                            ? '${tr('متصل الآن')} · ${tr('منذ')} ${_since(c['session_started'])}'
                            : '${tr('غير متصل')} · ${tr('آخر ظهور')} ${_ago(c['last_seen'])}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 13)),
                  ]),
            ),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _glassBtn(
                Icons.phone_outlined, phone, () => pageOpen('tel:$phone')),
            _glassBtn(Icons.copy_rounded, tr('نسخ الرقم'), () {
              Clipboard.setData(ClipboardData(text: phone));
              toast(context, tr('تم النسخ'));
            }),
            _glassBtn(
                Icons.chat_outlined,
                'WhatsApp',
                () => pageOpen(
                    'https://wa.me/973${phone.replaceAll(RegExp(r'\D'), '')}')),
          ]),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: .14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .3))),
              child: Row(children: [
                const Icon(Icons.place_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(on ? tr('يتصفح الآن') : tr('آخر مكان'),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 12)),
                        Text(place,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Row(children: [
          const Icon(Icons.route_rounded, size: 20),
          const SizedBox(width: 8),
          const Text('سجل التنقل',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          if ((c['area'] ?? '').toString().isNotEmpty)
            LuxPill('${c['area']}', const Color(0xFF475569),
                icon: Icons.location_city),
        ]),
      ),
      Flexible(
        child: FutureBuilder(
          future:
              sb.rpc('admin_customer_trail', params: {'p_user': c['user_id']}),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(errText(snap.error!)));
            }
            if (!snap.hasData) {
              return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()));
            }
            final rows = [
              for (final x in snap.data as List) Map<String, dynamic>.from(x)
            ];
            if (rows.isEmpty) {
              return const Empty('لم يتصفح التطبيق بعد',
                  icon: Icons.route_outlined);
            }
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              itemCount: rows.length,
              itemBuilder: (_, i) =>
                  _TrailRow(rows[i], first: i == 0, last: i == rows.length - 1),
            );
          },
        ),
      ),
    ]);
  }

  static String _since(dynamic at) {
    final t = DateTime.tryParse('$at')?.toLocal();
    if (t == null) return '—';
    final m = DateTime.now().difference(t).inMinutes;
    return m < 1
        ? tr('أقل من دقيقة')
        : m < 60
            ? '$m ${tr('دقيقة')}'
            : '${m ~/ 60} ${tr('ساعة')}';
  }

  Widget _glassBtn(IconData i, String t, VoidCallback f) => Material(
        color: Colors.white.withValues(alpha: .16),
        shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: .35))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(t,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _TrailRow extends StatelessWidget {
  const _TrailRow(this.r, {required this.first, required this.last});
  final Map<String, dynamic> r;
  final bool first, last;
  static const _tones = [
    [Color(0xFF6D3FD0), Color(0xFFB48CF5)],
    [Color(0xFFD9771F), Color(0xFFF7B955)],
    [Color(0xFF0F8C84), Color(0xFF4FD1B5)],
    [Color(0xFFB3264F), Color(0xFFF06A7A)],
    [Color(0xFF2463C9), Color(0xFF63B3F5)],
  ];
  IconData get _icon {
    final s = '${r['screen'] ?? ''}';
    if (s.contains('الدفع')) return Icons.payments_outlined;
    if (s.contains('الحجز')) return Icons.event_available_outlined;
    if (s.contains('الصنف')) return Icons.set_meal_outlined;
    if (s.contains('الملحمة')) return Icons.storefront_outlined;
    if (s.contains('طلب')) return Icons.receipt_long_outlined;
    if (s.contains('الإشعارات')) return Icons.notifications_outlined;
    if (s.contains('معلوماتي')) return Icons.person_outline;
    return Icons.home_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tones['${r['screen']}'.hashCode.abs() % _tones.length];
    final detail = [
      if ((r['store_name'] ?? '').toString().isNotEmpty) '${r['store_name']}',
      if ((r['product_name'] ?? '').toString().isNotEmpty)
        '${r['product_name']}',
    ].join(' · ');
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            Expanded(
                child: Container(
                    width: 2,
                    color: first ? Colors.transparent : Colors.black12)),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: tone),
                boxShadow: [
                  BoxShadow(
                      color: tone[0].withValues(alpha: .35), blurRadius: 8)
                ],
              ),
              child: Icon(_icon, size: 17, color: Colors.white),
            ),
            Expanded(
                child: Container(
                    width: 2,
                    color: last ? Colors.transparent : Colors.black12)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${r['screen'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (detail.isNotEmpty)
                    Text(detail,
                        style: TextStyle(
                            color: tone[0],
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(dateTimeText(r['at']),
              style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
        ),
      ]),
    );
  }
}
