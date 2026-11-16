import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import 'admin_activity.dart';
import 'admin_backups.dart';
import 'admin_domain.dart';
import 'admin_driver_money.dart';
import 'admin_drivers.dart';
import 'admin_merchants.dart';
import 'admin_money.dart';
import 'admin_offers.dart';
import 'admin_payouts.dart';
import 'admin_people.dart';
import 'admin_products.dart';

/// One section inside التحكم الإداري: its key (for permissions), name, line,
/// icon and its own gradient (dark → mid → light).
class HubSection {
  const HubSection(this.key, this.title, this.line, this.icon, this.stops,
      [this.accent = const Color(0xFFF4C752)]);
  final String key, title, line;

  /// Which group of the hub the tile sits in.
  String get group => switch (key) {
        'orders' ||
        'customers' ||
        'merchants' ||
        'products' ||
        'offers' ||
        'drivers' ||
        'zones' =>
          'ops',
        'wallet' ||
        'payouts' ||
        'cod' ||
        'driver_fees' ||
        'plans' ||
        'commissions' ||
        'reports' =>
          'money',
        _ => 'system',
      };
  final IconData icon;
  final List<Color> stops;
  final Color accent;

  Brand get brand => Brand(
      name: title,
      tagline: line,
      icon: icon,
      stops: stops,
      accent: accent,
      surface: const Color(0xFFF1F7FB));
}

const hubSections = <HubSection>[
  HubSection(
      'orders',
      'الطلبات',
      'تعديل وإيقاف وحذف وتحويل الطلبات',
      Icons.receipt_long_outlined,
      [Color(0xFF0B1F4D), Color(0xFF1C4790), Color(0xFF5FA6F2)]),
  HubSection(
      'customers',
      'العملاء',
      'حسابات العملاء وبياناتهم',
      Icons.people_outline,
      [Color(0xFF3E0820), Color(0xFF8E2442), Color(0xFFE07A86)]),
  HubSection(
      'merchants',
      'التجار',
      'المتاجر وتجميدها وإيقافها',
      Icons.storefront_outlined,
      [Color(0xFF043B33), Color(0xFF0D6152), Color(0xFF3CC4A0)]),
  HubSection(
      'products',
      'المنتجات',
      'أصناف كل الملاحم وأسعارها',
      Icons.inventory_2_outlined,
      [Color(0xFF3E2208), Color(0xFF9A4A12), Color(0xFFF2A65A)],
      Color(0xFFFFE3A3)),
  HubSection(
      'offers',
      'العروض',
      'خصومات كل المتاجر',
      Icons.local_offer_outlined,
      [Color(0xFF1E1450), Color(0xFF3A2878), Color(0xFF7A5AD4)]),
  HubSection(
      'reports',
      'تقارير التجار',
      'المبيعات والعمولات والصافي',
      Icons.bar_chart_outlined,
      [Color(0xFF073B4A), Color(0xFF136A82), Color(0xFF5CC8DA)]),
  HubSection(
      'drivers',
      'المندوبون',
      'الخريطة الحية وإسناد الطلبات',
      Icons.local_shipping_outlined,
      [Color(0xFF06375A), Color(0xFF0B6FB0), Color(0xFF47BFF0)]),
  HubSection(
      'notify',
      'الإشعارات',
      'رسائل وعروض للعملاء والتجار',
      Icons.campaign_outlined,
      [Color(0xFF2E1440), Color(0xFF6A3A8A), Color(0xFFB07AD0)]),
  HubSection(
      'activity',
      'سجل الأنشطة',
      'كل عملية في التطبيقات',
      Icons.manage_search,
      [Color(0xFF0A1628), Color(0xFF1F3A60), Color(0xFF4677B4)]),
  HubSection(
      'wallet',
      'محفظة المنصة',
      'دخل المنصة من العمولات والاشتراكات',
      Icons.account_balance_outlined,
      [Color(0xFF4A3208), Color(0xFF8A6416), Color(0xFFE2BC64)],
      Color(0xFFFFF1C9)),
  HubSection(
      'payouts',
      'طلبات السحب',
      'مراجعة وتحويل مستحقات التجار',
      Icons.outbox_outlined,
      [Color(0xFF0B3B33), Color(0xFF1E6B58), Color(0xFF3A9478)]),
  HubSection(
      'cod',
      'مبالغ الدفع عند الاستلام',
      'النقد الذي بحوزة المناديب',
      Icons.payments_outlined,
      [Color(0xFF5A2A0A), Color(0xFFB0581C), Color(0xFFF0A060)],
      Color(0xFFFFE6B8)),
  HubSection(
      'driver_fees',
      'رسوم المناديب',
      'مستحقات التوصيل ودفعها',
      Icons.delivery_dining_outlined,
      [Color(0xFF102A5C), Color(0xFF2A5DB0), Color(0xFF64B5F6)]),
  HubSection(
      'plans',
      'الاشتراكات',
      'باقات التجار وطلبات التجديد',
      Icons.workspace_premium_outlined,
      [Color(0xFF4A0E3C), Color(0xFF8E2470), Color(0xFFD86AB0)]),
  HubSection(
      'commissions',
      'العمولات',
      'عمولة التاجر والعميل',
      Icons.percent,
      [Color(0xFF5A0E14), Color(0xFFA8323A), Color(0xFFF07C6C)],
      Color(0xFFFFE0A8)),
  HubSection('zones', 'التوصيل', 'مناطق التوصيل ورسومها', Icons.map_outlined,
      [Color(0xFF043F3F), Color(0xFF0E7C7B), Color(0xFF4FD1C5)]),
  HubSection(
      'platform_users',
      'مستخدمو المنصة',
      'الحسابات والأدوار',
      Icons.admin_panel_settings_outlined,
      [Color(0xFF1C2533), Color(0xFF3D4F6B), Color(0xFF8AA0C0)]),
  HubSection(
      'domain',
      'الدومين',
      'عنوان التطبيق وربط دومين خاص',
      Icons.language,
      [Color(0xFF071A3A), Color(0xFF1A4C8C), Color(0xFF5BC6EE)],
      Color(0xFFB8F0FF)),
  HubSection(
      'backups',
      'النسخ الاحتياطية',
      'نسخ يومية وتنزيل كامل للبيانات',
      Icons.cloud_sync_outlined,
      [Color(0xFF062B26), Color(0xFF0F6A5C), Color(0xFF7CDCC0)],
      Color(0xFFF6D98A)),
];

/// The three groups of the hub, in order: key, title, icon.
const hubGroups = <(String, String, IconData)>[
  ('ops', 'العمليات اليومية', Icons.bolt_outlined),
  ('money', 'المال والحسابات', Icons.account_balance_wallet_outlined),
  ('system', 'النظام والإعدادات', Icons.tune),
];

/// Whether an admin may open a hub section (all on unless switched off).
bool secAllowed(dynamic perms, String key) =>
    perms is Map ? perms['sec_$key'] != false : true;

Widget hubPage(String key, Widget ordersBoard) => switch (key) {
      'orders' => ordersBoard,
      'customers' => const AdminUsers(group: UserGroup.customers),
      'merchants' => const AdminMerchants(),
      'products' => const AdminProducts(),
      'offers' => const AdminOffers(),
      'reports' => const AdminReports(),
      'drivers' => const AdminDriversHub(),
      'notify' => const AdminNotify(),
      'activity' => const AdminActivity(),
      'wallet' => const PlatformWallet(),
      'payouts' => const AdminPayouts(),
      'cod' => const AdminDriverMoney(fees: false),
      'driver_fees' => const AdminDriverMoney(fees: true),
      'plans' => const AdminPlans(),
      'commissions' => const AdminCommissions(),
      'zones' => const AdminZones(),
      'domain' => const AdminDomain(),
      'backups' => const AdminBackups(),
      _ => const AdminUsers(group: UserGroup.platform),
    };

/// The unlocked التحكم الإداري: a grid of gradient section tiles; a tile opens
/// that section in place (so the unlocked session stays), in its own colours.
class ControlHub extends StatefulWidget {
  const ControlHub(
      {super.key,
      required this.ordersBoard,
      required this.minutesLeft,
      required this.isSuper,
      required this.myPerms,
      required this.sectionSet,
      required this.onAccess,
      required this.onLock});
  final Widget ordersBoard;
  final int minutesLeft;
  final bool isSuper, sectionSet;
  final dynamic myPerms;
  final VoidCallback onAccess, onLock;
  @override
  State<ControlHub> createState() => _ControlHubState();
}

class _ControlHubState extends State<ControlHub> {
  HubSection? open;

  @override
  Widget build(BuildContext context) {
    final s = open;
    if (s != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SectionBar(section: s, onBack: () => setState(() => open = null)),
        Expanded(
            child: BrandScope(
                brand: s.brand, child: hubPage(s.key, widget.ordersBoard))),
      ]);
    }
    final visible = [
      for (final x in hubSections)
        if (widget.isSuper || secAllowed(widget.myPerms, x.key)) x
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060A18), Color(0xFF0B1531), Color(0xFF101A3C)]),
      ),
      child: Stack(children: [
        // Soft light pools behind the content.
        const PositionedDirectional(
            top: -140, end: -120, child: _Glow(Color(0xFFE7C077), 420, .16)),
        const PositionedDirectional(
            top: 380, start: -160, child: _Glow(Color(0xFF6C5CE7), 460, .14)),
        const PositionedDirectional(
            bottom: -180, end: 40, child: _Glow(Color(0xFF2EC4B6), 420, .10)),
        ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
          _HubHero(
            minutesLeft: widget.minutesLeft,
            sections: visible.length,
            isSuper: widget.isSuper,
            onAccess: widget.onAccess,
            onLock: widget.onLock,
          ),
          const SizedBox(height: 18),
          if (widget.isSuper && !widget.sectionSet) ...[
            _Glass(
              padding: const EdgeInsets.all(14),
              border: const Color(0xFFE7C077),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.key_outlined, color: Color(0xFFE7C077)),
                    const Text(
                        'دخلت بكلمة مرور حسابك. خصّص كلمة مرور خاصة لهذا القسم.',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE7C077),
                          foregroundColor: const Color(0xFF2A1A05)),
                      onPressed: widget.onAccess,
                      icon: const Icon(Icons.password_outlined),
                      label: const Text('تحديد كلمة مرور القسم'),
                    ),
                  ]),
            ),
            const SizedBox(height: 18),
          ],
          for (final g in hubGroups)
            if (visible.any((x) => x.group == g.$1)) ...[
              _GroupHeader(
                  title: g.$2,
                  icon: g.$3,
                  count: visible.where((x) => x.group == g.$1).length),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final cols = (c.maxWidth / 250).floor().clamp(2, 5);
                final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final x in visible.where((x) => x.group == g.$1))
                    SizedBox(
                        width: w,
                        child: _HubTile(
                            section: x, onTap: () => setState(() => open = x))),
                ]);
              }),
              const SizedBox(height: 24),
            ],
        ]),
      ]),
    );
  }
}

const _gold = [Color(0xFFF8E3A8), Color(0xFFE7C077), Color(0xFFB8893A)];

/// A soft radial light.
class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size, this.alpha);
  final Color color;
  final double size, alpha;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0)
              ])),
        ),
      );
}

/// Frosted glass panel with a thin luminous border.
class _Glass extends StatelessWidget {
  const _Glass(
      {required this.child,
      this.padding = const EdgeInsets.all(18),
      this.border = Colors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color border;
  static const double radius = 26;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Colors.white.withValues(alpha: .10),
                Colors.white.withValues(alpha: .03),
              ]),
          border: Border.all(color: border.withValues(alpha: .28)),
        ),
        child: child,
      );
}

class _HubHero extends StatelessWidget {
  const _HubHero(
      {required this.minutesLeft,
      required this.sections,
      required this.isSuper,
      required this.onAccess,
      required this.onLock});
  final int minutesLeft, sections;
  final bool isSuper;
  final VoidCallback onAccess, onLock;

  Widget _chip(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: c.withValues(alpha: .14),
            border: Border.all(color: c.withValues(alpha: .45))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: c),
          const SizedBox(width: 6),
          Text(t,
              style: TextStyle(
                  color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _btn(IconData i, String t, VoidCallback f, {bool gold = false}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: f,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: gold
                  ? const LinearGradient(colors: _gold)
                  : LinearGradient(colors: [
                      Colors.white.withValues(alpha: .14),
                      Colors.white.withValues(alpha: .06)
                    ]),
              border: Border.all(
                  color: gold
                      ? const Color(0xFFF8E3A8)
                      : Colors.white.withValues(alpha: .25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i,
                  size: 18,
                  color: gold ? const Color(0xFF3A2606) : Colors.white),
              const SizedBox(width: 8),
              Text(t,
                  style: TextStyle(
                      color: gold ? const Color(0xFF3A2606) : Colors.white,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color(0xFF14204A), Color(0xFF1F2C66), Color(0xFF3B2F6E)]),
        border:
            Border.all(color: const Color(0xFFE7C077).withValues(alpha: .4)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: .45),
              blurRadius: 30,
              offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(children: [
          PositionedDirectional(
              end: -60,
              top: -80,
              child: _Glow(const Color(0xFFE7C077), 280, .22)),
          PositionedDirectional(
              start: -40,
              bottom: -90,
              child: _Glow(const Color(0xFF7C6CF0), 240, .2)),
          // Thin gold rule along the top edge.
          Positioned(
              top: 0,
              left: 40,
              right: 40,
              child: Container(
                  height: 1.4,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                    const Color(0xFFE7C077).withValues(alpha: 0),
                    const Color(0xFFF8E3A8),
                    const Color(0xFFE7C077).withValues(alpha: 0),
                  ])))),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Wrap(
              spacing: 20,
              runSpacing: 18,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _gold),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFFE7C077).withValues(alpha: .45),
                            blurRadius: 22)
                      ],
                    ),
                    child: const Icon(Icons.shield_moon_outlined,
                        color: Color(0xFF3A2606), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(colors: [
                            Colors.white,
                            Color(0xFFF8E3A8),
                          ]).createShader(r),
                          child: const Text('التحكم الإداري',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 4),
                        const Text('مركز التحكم الكامل في المنصة',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13.5)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _chip(Icons.lock_open_rounded, tr('الجلسة مفتوحة'),
                              const Color(0xFF7CE0B5)),
                          _chip(
                              Icons.timer_outlined,
                              '${tr('تُقفل بعد')} $minutesLeft ${tr('دقيقة')}',
                              const Color(0xFFF8E3A8)),
                          _chip(
                              Icons.grid_view_rounded,
                              '$sections ${tr('قسم')}',
                              const Color(0xFFB9C6FF)),
                        ]),
                      ]),
                ]),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  if (isSuper)
                    _btn(Icons.admin_panel_settings_outlined,
                        tr('الصلاحيات وكلمات المرور'), onAccess,
                        gold: true),
                  _btn(Icons.lock_outline, tr('قفل القسم'), onLock),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(
      {required this.title, required this.icon, required this.count});
  final String title;
  final IconData icon;
  final int count;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(colors: _gold)),
          child: Icon(icon, size: 19, color: const Color(0xFF3A2606)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('$count',
            style: const TextStyle(color: Color(0xFFE7C077), fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                const Color(0xFFE7C077).withValues(alpha: .6),
                const Color(0xFFE7C077).withValues(alpha: 0),
              ]))),
        ),
      ]);
}

class _HubTile extends StatefulWidget {
  const _HubTile({required this.section, required this.onTap});
  final HubSection section;
  final VoidCallback onTap;
  @override
  State<_HubTile> createState() => _HubTileState();
}

class _HubTileState extends State<_HubTile> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final st = section.stops;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: hover ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          // Luminous gradient border.
          padding: const EdgeInsets.all(1.3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  section.accent.withValues(alpha: .9),
                  st.last.withValues(alpha: .25),
                  section.accent.withValues(alpha: .5),
                ]),
            boxShadow: [
              BoxShadow(
                  color: st[1].withValues(alpha: hover ? .55 : .35),
                  blurRadius: hover ? 28 : 18,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(23),
              child: Ink(
                height: 156,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: st),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(children: [
                    // Diagonal sheen.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [
                                0,
                                .45,
                                .46,
                                1
                              ],
                              colors: [
                                Colors.white.withValues(alpha: .16),
                                Colors.white.withValues(alpha: .02),
                                Colors.white.withValues(alpha: 0),
                                Colors.black.withValues(alpha: .12),
                              ]),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                        end: -40,
                        top: -40,
                        child: _Glow(section.accent, 150, .32)),
                    // Large faint icon as a watermark.
                    PositionedDirectional(
                      end: -14,
                      bottom: -18,
                      child: Icon(section.icon,
                          size: 110,
                          color: Colors.white.withValues(alpha: .07)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [
                                    Colors.white.withValues(alpha: .28),
                                    Colors.white.withValues(alpha: .08),
                                  ]),
                                  border: Border.all(
                                      color:
                                          section.accent.withValues(alpha: .85),
                                      width: 1.3),
                                ),
                                child: Icon(section.icon,
                                    color: section.accent, size: 24),
                              ),
                              const Spacer(),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: hover ? .26 : .12)),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    size: 14, color: Colors.white),
                              ),
                            ]),
                            const Spacer(),
                            Text(section.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(section.line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .78),
                                    fontSize: 12)),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.section, required this.onBack});
  final HubSection section;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: section.stops),
          border: Border(
              bottom: BorderSide(
                  color: section.accent.withValues(alpha: .6), width: 1.2)),
          boxShadow: [
            BoxShadow(
                color: section.stops.first.withValues(alpha: .4),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Material(
            color: Colors.white.withValues(alpha: .14),
            shape: StadiumBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: .3))),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grid_view_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('التحكم الإداري',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_left, color: Colors.white54),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .14),
                border:
                    Border.all(color: section.accent.withValues(alpha: .7))),
            child: Icon(section.icon, color: section.accent, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(section.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}
