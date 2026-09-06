import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../services/profile_store.dart';
import 'room_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final store = ProfileStore();
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await store.history();
    if (mounted) setState(() { items = value; loading = false; });
  }

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      final room = await ApiService().getRoom(item['code'] as String);
      final userId = await store.userId();
      final name = await store.displayName();
      final isHost = room.hostUserId == userId;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(
        room: room,
        userId: userId,
        displayName: name,
        isHost: isHost,
        localSource: isHost ? item['localSource'] as String? : null,
      )));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
        children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rooms', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('Your recent watch rooms', style: TextStyle(color: AppColors.muted)),
            ])),
            if (items.isNotEmpty) IconButton(onPressed: () async { await store.clearHistory(); await _load(); }, icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          const SizedBox(height: 24),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          if (!loading && items.isEmpty) _empty(),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _open(item),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(16)), child: Icon(_icon(item['sourceType'] as String?))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['name'] as String? ?? 'Room', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('${item['code']}  •  ${_source(item['sourceType'] as String?)}', style: const TextStyle(color: AppColors.muted)),
                  ])),
                  if (item['createdByMe'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.workspace_premium_rounded, color: AppColors.violet, size: 20)),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ]),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _empty() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
    child: const Column(children: [Icon(Icons.groups_rounded, size: 48, color: AppColors.indigo), SizedBox(height: 14), Text('No recent rooms yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Rooms you create or join will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))]),
  );

  IconData _icon(String? value) => switch (value) {
    'local' => Icons.insert_drive_file_rounded,
    'screen_share' => Icons.screen_share_rounded,
    _ => Icons.play_circle_fill_rounded,
  };
  String _source(String? value) => switch (value) {
    'local' => 'From Device',
    'screen_share' => 'Screen Share',
    _ => 'YouTube',
  };
}
