import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alert_bridge_stub.dart'
    if (dart.library.js_interop) 'alert_bridge_web.dart';
import 'brand.dart';
import 'common.dart';
import 'i18n.dart';
import 'push.dart';
import 'ttext.dart';

RealtimeChannel _watch(String table, String driverId, void Function() cb) => sb
    .channel('$table-$driverId-${DateTime.now().microsecondsSinceEpoch}')
    .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId),
        callback: (_) => cb())
    .subscribe();

/// Live text chat between the admins and one driver.
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.driverId, required this.admin});
  final String driverId;

  /// True on the admin side; messages "from me" are then the admin's.
  final bool admin;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final msgs = <Map<String, dynamic>>[];
  final text = TextEditingController();
  final scroll = ScrollController();
  RealtimeChannel? ch;
  Timer? poll;
  bool loading = true;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    load();
    ch = _watch('driver_chat', widget.driverId, load);
    poll = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  @override
  void dispose() {
    poll?.cancel();
    if (ch != null) sb.removeChannel(ch!);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await sb
          .from('driver_chat')
          .select()
          .eq('driver_id', widget.driverId)
          .order('created_at')
          .limit(300);
      if (!mounted) return;
      final grew = r.length != msgs.length;
      setState(() {
        msgs
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(r));
        loading = false;
      });
      final unread = msgs.any((m) =>
          m['read_at'] == null && (m['from_admin'] == true) != widget.admin);
      if (unread) {
        await sb.rpc('chat_mark_read', params: {'p_driver': widget.driverId});
      }
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final t = text.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await sb
          .rpc('chat_send', params: {'p_driver': widget.driverId, 'p_body': t});
      text.clear();
      await load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return Column(children: [
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : msgs.isEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        widget.admin
                            ? 'لا توجد رسائل بعد. اكتب أول رسالة للمندوب.'
                            : 'لا توجد رسائل بعد. اكتب للإدارة هنا.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black45)),
                  ))
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (c, i) {
                      final m = msgs[i];
                      final mine = (m['from_admin'] == true) == widget.admin;
                      return Align(
                        alignment: mine
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: mine
                                ? LinearGradient(colors: b.stops.sublist(1))
                                : null,
                            color: mine ? null : const Color(0xFFF0F2F6),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m['body']}',
                                    style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : Colors.black87)),
                                const SizedBox(height: 2),
                                Text(
                                    '${dateTimeText(m['created_at'])}${mine && m['read_at'] != null ? ' · ${tr('مقروءة')}' : ''}',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: mine
                                            ? Colors.white70
                                            : Colors.black45)),
                              ]),
                        ),
                      );
                    },
                  ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: text,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration:
                  InputDecoration(isDense: true, hintText: tr('اكتب رسالتك…')),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : send,
            style: IconButton.styleFrom(backgroundColor: b.primary),
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    ]);
  }
}

/// Admin side: chat with one driver in a dialog.
Future<void> openDriverChat(
        BuildContext context, String driverId, String name) =>
    showDialog(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 460,
          height: 560,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: brandOf(context).stops.sublist(1))),
              child: Row(children: [
                const Icon(Icons.forum_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${tr('دردشة مع')} $name',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Expanded(child: ChatPanel(driverId: driverId, admin: true)),
          ]),
        ),
      ),
    );

/// Driver side: the chat with the admins as a page.
class DriverChatPage extends StatelessWidget {
  const DriverChatPage({super.key, required this.driverId});
  final String driverId;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const GradientAppBar(title: Text('دردشة الإدارة')),
        body: ChatPanel(driverId: driverId, admin: false),
      );
}

/// Driver app bar button with the number of unread admin messages.
class DriverChatButton extends StatefulWidget {
  const DriverChatButton({super.key, required this.driverId});
  final String driverId;
  @override
  State<DriverChatButton> createState() => _DriverChatButtonState();
}

class _DriverChatButtonState extends State<DriverChatButton> {
  int unread = 0;
  RealtimeChannel? ch;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    count();
    ch = _watch('driver_chat', widget.driverId, count);
    poll = Timer.periodic(const Duration(seconds: 20), (_) => count());
  }

  @override
  void dispose() {
    poll?.cancel();
    if (ch != null) sb.removeChannel(ch!);
    super.dispose();
  }

  Future<void> count() async {
    try {
      final r = await sb
          .from('driver_chat')
          .select('id')
          .eq('driver_id', widget.driverId)
          .eq('from_admin', true)
          .isFilter('read_at', null);
      if (mounted) setState(() => unread = r.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('دردشة الإدارة'),
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DriverChatPage(driverId: widget.driverId)));
          count();
        },
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: const Icon(Icons.forum_outlined),
        ),
      );
}

/// Driver app: rings loudly when the admin nudges, until the driver taps OK.
class NudgeWatcher extends StatefulWidget {
  const NudgeWatcher({super.key, required this.driverId, required this.child});
  final String driverId;
  final Widget child;
  @override
  State<NudgeWatcher> createState() => _NudgeWatcherState();
}

class _NudgeWatcherState extends State<NudgeWatcher> {
  RealtimeChannel? ch;
  Timer? poll;
  bool showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
    ch = _watch('driver_nudges', widget.driverId, check);
    poll = Timer.periodic(const Duration(seconds: 15), (_) => check());
  }

  @override
  void dispose() {
    poll?.cancel();
    if (ch != null) sb.removeChannel(ch!);
    super.dispose();
  }

  Future<void> check() async {
    if (showing || !mounted) return;
    try {
      final r = await sb
          .from('driver_nudges')
          .select()
          .eq('driver_id', widget.driverId)
          .isFilter('seen_at', null)
          .gte(
              'created_at',
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);
      if (r.isEmpty || !mounted) return;
      final n = r.first;
      showing = true;
      alertPlay();
      if (!pushOn.value) {
        alertNotify(tr('نكز من الإدارة'),
            '${n['note'] ?? tr('الإدارة تطلب انتباهك الآن')}');
      }
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.notifications_active,
              size: 46, color: Color(0xFFE0533D)),
          title: const Text('نكز من الإدارة'),
          content: Text('${n['note'] ?? tr('الإدارة تطلب انتباهك الآن')}',
              textAlign: TextAlign.center),
          actions: [
            TextButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DriverChatPage(driverId: widget.driverId)));
                },
                icon: const Icon(Icons.forum_outlined),
                label: const Text('رد على الإدارة')),
            FilledButton(
                onPressed: () => Navigator.pop(c), child: const Text('تم')),
          ],
        ),
      );
      alertStop();
      await sb.rpc('driver_nudge_seen', params: {'p_id': n['id']});
    } catch (_) {
    } finally {
      showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
