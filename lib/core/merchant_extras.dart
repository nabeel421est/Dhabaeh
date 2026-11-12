import 'package:flutter/material.dart' hide Text;
import 'package:latlong2/latlong.dart';

import 'address_map.dart';
import 'brand.dart';
import 'common.dart';
import 'i18n.dart';
import 'ttext.dart';

/// Week days, Saturday first, as stored in merchants.work_hours.
const weekDays = <(String, String)>[
  ('sat', 'السبت'),
  ('sun', 'الأحد'),
  ('mon', 'الاثنين'),
  ('tue', 'الثلاثاء'),
  ('wed', 'الأربعاء'),
  ('thu', 'الخميس'),
  ('fri', 'الجمعة'),
];

Map<String, dynamic> defaultHours() => {
      for (final d in weekDays)
        d.$1: {'open': true, 'from': '07:00', 'to': '22:00'}
    };

Map<String, dynamic> hoursOf(dynamic v) {
  final base = defaultHours();
  if (v is Map) {
    for (final d in weekDays) {
      if (v[d.$1] is Map) base[d.$1] = Map<String, dynamic>.from(v[d.$1]);
    }
  }
  return base;
}

String _fmt(String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 0;
  final m = p.length > 1 ? p[1] : '00';
  final am = h < 12;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${tr(am ? 'ص' : 'م')}';
}

String dayHoursText(Map d) => d['open'] == true
    ? '${_fmt('${d['from']}')} - ${_fmt('${d['to']}')}'
    : tr('مغلق');

/// Seven rows: open switch plus from/to times.
class WorkHoursEditor extends StatelessWidget {
  const WorkHoursEditor(
      {super.key, required this.value, required this.onChanged});
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  Future<void> pickTime(
      BuildContext context, String day, String key, String cur) async {
    final p = cur.split(':');
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: int.tryParse(p.first) ?? 7,
            minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0));
    if (t == null) return;
    final v = Map<String, dynamic>.from(value);
    v[day] = {
      ...Map<String, dynamic>.from(v[day]),
      key:
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
    };
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final tone = brandOf(context).primary;
    return Column(children: [
      for (final d in weekDays)
        Builder(builder: (context) {
          final h = Map<String, dynamic>.from(value[d.$1] ?? {});
          final open = h['open'] == true;
          Widget time(String k) => OutlinedButton.icon(
                onPressed: open
                    ? () => pickTime(context, d.$1, k, '${h[k] ?? '07:00'}')
                    : null,
                icon: const Icon(Icons.schedule, size: 16),
                label: Text(_fmt('${h[k] ?? '07:00'}')),
              );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                  width: 78,
                  child: Text(d.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Switch(
                value: open,
                activeThumbColor: tone,
                onChanged: (v) {
                  final n = Map<String, dynamic>.from(value);
                  n[d.$1] = {...h, 'open': v};
                  onChanged(n);
                },
              ),
              const SizedBox(width: 6),
              if (open) ...[
                Flexible(child: time('from')),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('إلى')),
                Flexible(child: time('to')),
              ] else
                const Text('مغلق', style: TextStyle(color: Colors.black45)),
            ]),
          );
        }),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () {
            final sat = Map<String, dynamic>.from(value['sat'] ?? {});
            onChanged({for (final d in weekDays) d.$1: Map.of(sat)});
          },
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('تطبيق أوقات السبت على كل الأيام'),
        ),
      ),
    ]);
  }
}

/// Read-only list of the week's hours.
class WorkHoursView extends StatelessWidget {
  const WorkHoursView({super.key, required this.hours});
  final dynamic hours;
  @override
  Widget build(BuildContext context) {
    final h = hoursOf(hours);
    return Column(children: [
      for (final d in weekDays)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 90, child: Text(d.$2)),
            Expanded(
                child: Text(dayHoursText(h[d.$1]),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: h[d.$1]['open'] == true
                            ? Colors.black87
                            : Colors.black38))),
          ]),
        ),
    ]);
  }
}

/// How close a date is: expired (red), within 10 days (amber), fine (green).
(String, Color) expiryState(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  if (d == null) return (tr('لا يوجد تاريخ'), Colors.blueGrey);
  final today = DateTime.now();
  final left = DateTime(d.year, d.month, d.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (left < 0) {
    return ('${tr('منتهية منذ')} ${-left} ${tr('يوم')}', G.ruby.first);
  }
  if (left <= 10) {
    return ('${tr('تنتهي بعد')} $left ${tr('يوم')}', G.amber.first);
  }
  return ('${tr('سارية حتى')} ${dateText(v)}', G.emerald.first);
}

/// A tappable date field (used for document expiry dates).
class DateField extends StatelessWidget {
  const DateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onPick,
      this.required = true,
      this.showError = false,
      this.color});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final bool required;
  final bool showError;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? brandOf(context).primary;
    final st = value == null ? null : expiryState(isoDate(value!));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now().add(const Duration(days: 365)),
            firstDate: DateTime(2015),
            lastDate: DateTime(2045));
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr(required ? '$label *' : label),
          errorText:
              showError && required && value == null ? tr('مطلوب') : null,
          helperText: st?.$1,
          helperStyle: TextStyle(color: st?.$2, fontWeight: FontWeight.w700),
          prefixIcon: Icon(Icons.event_outlined, color: tone),
          filled: true,
          fillColor: tone.withValues(alpha: .04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.withValues(alpha: .18))),
        ),
        child: Text(
            value == null ? tr('اختر التاريخ') : dateText(isoDate(value!)),
            style: TextStyle(color: value == null ? Colors.black38 : null)),
      ),
    );
  }
}

/// Store location: pick the city, then the block, and the map jumps there;
/// a tap on the map fine-tunes the pin.
class StoreLocator extends StatefulWidget {
  const StoreLocator(
      {super.key,
      required this.city,
      required this.block,
      required this.pin,
      required this.onCity,
      required this.onPin,
      this.road,
      this.building});
  final String? city;
  final TextEditingController block;
  final TextEditingController? road;
  final TextEditingController? building;
  final LatLng? pin;
  final ValueChanged<String?> onCity;
  final ValueChanged<LatLng> onPin;
  @override
  State<StoreLocator> createState() => _StoreLocatorState();
}

class _StoreLocatorState extends State<StoreLocator> {
  bool busy = false;
  String? note;

  Future<void> locate() async {
    if (widget.city == null && widget.block.text.trim().isEmpty) {
      setState(() => note = tr('اختر المدينة ثم اكتب رقم المجمع'));
      return;
    }
    setState(() {
      busy = true;
      note = null;
    });
    final p = await geocodeBahrain(
        city: widget.city,
        area: widget.city,
        block: widget.block.text.trim(),
        road: widget.road?.text.trim(),
        building: widget.building?.text.trim());
    if (!mounted) return;
    setState(() {
      busy = false;
      note = p == null
          ? tr('لم نجد الموقع، حدده بالضغط على الخريطة')
          : tr('تم تحديد المجمع. اضغط على الخريطة لضبط مكان المحل بدقة');
    });
    if (p != null) widget.onPin(p);
  }

  @override
  Widget build(BuildContext context) {
    final tone = G.amber.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final two = box.maxWidth >= 520;
        final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: w,
            child: DropdownButtonFormField<String>(
              initialValue:
                  bahrainCities.contains(widget.city) ? widget.city : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('1. المدينة'),
                prefixIcon: Icon(Icons.location_city_outlined, color: tone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final c in bahrainCities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: widget.onCity,
            ),
          ),
          SizedBox(
            width: w,
            child: TextField(
              controller: widget.block,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => locate(),
              decoration: InputDecoration(
                labelText: tr('2. المجمع'),
                prefixIcon: Icon(Icons.grid_view_outlined, color: tone),
                suffixIcon: IconButton(
                  tooltip: tr('حدد على الخريطة'),
                  onPressed: busy ? null : locate,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.travel_explore, color: tone),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]);
      }),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: tone),
            onPressed: busy ? null : locate,
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text('حدد موقع المحل من المدينة والمجمع'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final p = await guard(context, () => currentLocation());
                  if (p != null) widget.onPin(p);
                },
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('موقعي الحالي'),
        ),
      ]),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(note!,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        ),
      const SizedBox(height: 8),
      AddressMap(point: widget.pin, height: 240, onPick: widget.onPin),
      if (widget.pin != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              '${widget.pin!.latitude.toStringAsFixed(5)}, ${widget.pin!.longitude.toStringAsFixed(5)}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ),
    ]);
  }
}

/// Red or amber strip listing a store's documents that expired or expire
/// within 10 days. Shows nothing when all are fine.
class DocAlertsBanner extends StatelessWidget {
  const DocAlertsBanner({super.key, required this.merchantId});
  final String merchantId;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('docs-$merchantId'),
        future: () async {
          try {
            return List<Map<String, dynamic>>.from(await sb.rpc(
                    'merchant_doc_alerts',
                    params: {'p_merchant': merchantId}) ??
                []);
          } catch (_) {
            return <Map<String, dynamic>>[];
          }
        }(),
        builder: (context, snap) {
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const SizedBox.shrink();
          final expired = rows.any((r) => toNum(r['days_left']) < 0);
          final tone = expired ? G.ruby : G.amber;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: tone),
              boxShadow: [
                BoxShadow(
                    color: tone.first.withValues(alpha: .3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.flag, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          expired
                              ? 'وثيقة منتهية، جدّدها وأرسلها للإدارة'
                              : 'وثيقة تقترب من الانتهاء',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      for (final r in rows)
                        Text(
                            '${tr('${r['label']}')}: ${expiryState(r['expiry']).$1} (${dateText(r['expiry'])})',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5)),
                    ]),
              ),
            ]),
          );
        },
      );
}
