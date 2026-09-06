import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../services/profile_store.dart';
import 'room_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final code = TextEditingController();
  final store = ProfileStore();
  bool loading = false;

  @override
  void dispose() { code.dispose(); super.dispose(); }

  Future<void> _find() async {
    final value = code.text.trim().toUpperCase();
    if (value.length < 4) return;
    setState(() => loading = true);
    try {
      final room = await ApiService().getRoom(value);
      final userId = await store.userId();
      final name = await store.displayName();
      await store.rememberRoom(room, createdByMe: room.hostUserId == userId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(room: room, userId: userId, displayName: name, isHost: room.hostUserId == userId)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
    children: [
      const Text('Search', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Find a private room by its code.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: code, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => _find(), style: const TextStyle(letterSpacing: 5, fontSize: 22, fontWeight: FontWeight.w900), decoration: const InputDecoration(labelText: 'Room code', prefixIcon: Icon(Icons.search_rounded), hintText: 'AB12CD')),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: loading ? null : _find, icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.meeting_room_rounded), label: const Text('Find room'), style: FilledButton.styleFrom(backgroundColor: AppColors.indigo, padding: const EdgeInsets.symmetric(vertical: 17))),
        ]),
      ),
      const SizedBox(height: 24),
      const _Tip(icon: Icons.link_rounded, title: 'Invite link', text: 'A host can share the six-character code from the room header.'),
      const SizedBox(height: 12),
      const _Tip(icon: Icons.lock_outline_rounded, title: 'Private by default', text: 'V1 rooms are discoverable only when you know the room code.'),
    ],
  );
}

class _Tip extends StatelessWidget {
  final IconData icon; final String title, text;
  const _Tip({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppColors.indigo), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(text, style: const TextStyle(color: AppColors.muted, height: 1.35))]))]));
}
