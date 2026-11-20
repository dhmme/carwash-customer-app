import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../session.dart';
import '../worker_localization.dart';

class WorkerBonusCard extends StatefulWidget {
  final String baseUrl;
  final WorkerLocalizations localizations;
  const WorkerBonusCard({super.key, required this.baseUrl, required this.localizations});
  @override
  WorkerBonusCardState createState() => WorkerBonusCardState();
}

class WorkerBonusCardState extends State<WorkerBonusCard> with WidgetsBindingObserver {
  Map<String, dynamic>? _bonus;
  bool _fetching = false, _failed = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) refresh();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      var response = await http.get(Uri.parse('${widget.baseUrl}/api/worker/bonus/'), headers: Session.authHeaders);
      if (response.statusCode == 401 && await Session.refresh()) {
        response = await http.get(Uri.parse('${widget.baseUrl}/api/worker/bonus/'), headers: Session.authHeaders);
      }
      if (response.statusCode != 200) throw Exception();
      final data = Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
      if (mounted) setState(() { _bonus = data; _failed = false; });
    } catch (_) {
      if (mounted) setState(() { _failed = true; _bonus = null; });
    } finally {
      _fetching = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    final l = widget.localizations;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 38),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.monthlyBonus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (_bonus != null) ...[
            Text('${_bonus!['amount']} ${l.bonusCurrency}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text('${_bonus!['month']} • ${l.bonusRecordedByManager}'),
          ] else if (_failed) Text(l.bonusLoadFailed)
          else const LinearProgressIndicator(),
        ])),
        if (_failed) IconButton(onPressed: refresh, icon: const Icon(Icons.refresh), tooltip: l.refresh),
      ])),
    );
  }
}
