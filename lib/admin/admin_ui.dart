import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';

/// Calls an edge function and throws its Arabic error text on failure.
Future<Map<String, dynamic>> edgeFn(
    String name, Map<String, dynamic> body) async {
  try {
    final r = await sb.functions.invoke(name, body: body);
    final d = r.data;
    if (d is Map && d['error'] == null) return Map<String, dynamic>.from(d);
    throw Exception(d is Map ? d['error'] : 'خطأ');
  } on FunctionException catch (e) {
    final d = e.details;
    throw Exception(d is Map ? d['error'] ?? 'خطأ' : 'خطأ');
  }
}

/// Yes / no dialog. Returns true only on the confirm button.
Future<bool> askSure(BuildContext context, String title, String body,
    {String yes = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء')),
        FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E))
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

/// Luxurious opening banner for a control section: deep gradient from the
/// section's own identity, soft lights, a metallic emblem and headline stats.
class LuxHero extends StatelessWidget {
  const LuxHero(
      {super.key,
      required this.title,
      required this.line,
      this.stats = const [],
      this.actions = const []});
  final String title, line;
  final List<(IconData, String, String)> stats;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: b.gradient,
        boxShadow: [
          BoxShadow(
              color: b.dark.withValues(alpha: .45),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          PositionedDirectional(
              end: -70, top: -90, child: _light(b.accent, 300, .30)),
          PositionedDirectional(
              start: -50, bottom: -110, child: _light(b.stops[2], 260, .35)),
          PositionedDirectional(
            end: 16,
            bottom: -26,
            child: Icon(b.icon,
                size: 150, color: Colors.white.withValues(alpha: .07)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(b.accent, Colors.white, .5)!,
                          b.accent,
                          Color.lerp(b.accent, Colors.black, .3)!,
                        ]),
                    boxShadow: [
                      BoxShadow(
                          color: b.accent.withValues(alpha: .5), blurRadius: 20)
                    ],
                  ),
                  child: Icon(b.icon, color: b.dark, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(line,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontSize: 13)),
                      ]),
                ),
              ]),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final s in stats) _stat(s.$1, s.$2, s.$3, b),
                ]),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _light(Color c, double size, double a) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [c.withValues(alpha: a), c.withValues(alpha: 0)])),
        ),
      );

  Widget _stat(IconData i, String k, String v, Brand b) => Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: .12),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 18, color: b.accent),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .7), fontSize: 11.5)),
            Text(v,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ]),
        ]),
      );
}

/// Gold / glass button used on [LuxHero].
class LuxButton extends StatelessWidget {
  const LuxButton(this.icon, this.label, this.onTap,
      {super.key, this.filled = true});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    final fg = filled ? b.dark : Colors.white;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: filled
                  ? LinearGradient(colors: [
                      Color.lerp(b.accent, Colors.white, .45)!,
                      b.accent,
                    ])
                  : LinearGradient(colors: [
                      Colors.white.withValues(alpha: .18),
                      Colors.white.withValues(alpha: .07),
                    ]),
              border: Border.all(
                  color: filled
                      ? Colors.white.withValues(alpha: .6)
                      : Colors.white.withValues(alpha: .3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// White card with a thin gradient top edge and an icon title.
class LuxCard extends StatelessWidget {
  const LuxCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.child,
      this.trailing});
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: b.primary.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
              color: b.dark.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 4, decoration: BoxDecoration(gradient: b.gradient)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: b.soft),
                      child: Icon(icon, size: 20, color: b.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: b.dark))),
                    if (trailing != null) trailing!,
                  ]),
                  const SizedBox(height: 14),
                  child,
                ]),
          ),
        ]),
      ),
    );
  }
}

/// Small coloured status pill.
class LuxPill extends StatelessWidget {
  const LuxPill(this.text, this.color, {super.key, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: color.withValues(alpha: .12),
            border: Border.all(color: color.withValues(alpha: .4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Soft tinted page background for a control section.
class LuxPage extends StatelessWidget {
  const LuxPage({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(b.stops[2], Colors.white, .9)!,
              const Color(0xFFF7F8FC),
            ]),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            c,
          ]
        ],
      ),
    );
  }
}
