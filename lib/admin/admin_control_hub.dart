import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import 'admin_activity.dart';
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
    return ListView(padding: const EdgeInsets.all(16), children: [
      PageHero(
        icon: Icons.admin_panel_settings_outlined,
        title: 'التحكم الإداري',
        subtitle:
            '${tr('الجلسة مفتوحة')} · ${tr('تُقفل بعد')} ${widget.minutesLeft} ${tr('دقيقة')}',
        stats: [('الأقسام', '${visible.length}')],
        action: Wrap(spacing: 8, runSpacing: 8, children: [
          if (widget.isSuper)
            HeroButton(
                icon: Icons.admin_panel_settings_outlined,
                label: 'الصلاحيات وكلمات المرور',
                onPressed: widget.onAccess),
          HeroButton(
              icon: Icons.lock_outline,
              label: 'قفل القسم',
              onPressed: widget.onLock),
        ]),
      ),
      const SizedBox(height: 16),
      if (widget.isSuper && !widget.sectionSet) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              G.amber.last.withValues(alpha: .18),
              G.gold.last.withValues(alpha: .10)
            ]),
            border: Border.all(color: G.amber.first.withValues(alpha: .35)),
          ),
          child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.key_outlined, color: G.amber.first),
                const Text(
                    'دخلت بكلمة مرور حسابك. خصّص كلمة مرور خاصة لهذا القسم.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: G.amber.first),
                  onPressed: widget.onAccess,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('تحديد كلمة مرور القسم'),
                ),
              ]),
        ),
        const SizedBox(height: 16),
      ],
      LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 250).floor().clamp(2, 5);
        final w = (c.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final x in visible)
            SizedBox(
                width: w,
                child: _HubTile(
                    section: x, onTap: () => setState(() => open = x))),
        ]);
      }),
    ]);
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.section, required this.onTap});
  final HubSection section;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final st = section.stops;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: st),
            border: Border.all(color: section.accent.withValues(alpha: .45)),
            boxShadow: [
              BoxShadow(
                  color: st[1].withValues(alpha: .32),
                  blurRadius: 18,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Stack(children: [
            PositionedDirectional(
                end: -34,
                top: -34,
                child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: .24),
                          Colors.white.withValues(alpha: 0)
                        ])))),
            PositionedDirectional(
                start: -26,
                bottom: -40,
                child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .07)))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: .16),
                        border: Border.all(
                            color: section.accent.withValues(alpha: .7)),
                      ),
                      child:
                          Icon(section.icon, color: section.accent, size: 24),
                    ),
                    const Spacer(),
                    Text(section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(section.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
          ]),
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
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: section.stops)),
        child: Row(children: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('التحكم الإداري'),
          ),
          const Icon(Icons.chevron_left, color: Colors.white54),
          Icon(section.icon, color: section.accent, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(section.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}
