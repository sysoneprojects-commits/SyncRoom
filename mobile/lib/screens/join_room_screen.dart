import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../services/profile_store.dart';
import 'room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final code = TextEditingController();
  final name = TextEditingController(text: 'Guest');
  bool loading = false;
  final profile = ProfileStore();

  @override
  void initState() {
    super.initState();
    profile.displayName().then((value) { if (mounted) setState(() => name.text = value); });
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> join() async {
    if (code.text.trim().length < 4) return;
    setState(() => loading = true);
    try {
      final room = await ApiService().getRoom(code.text.trim());
      final id = await profile.userId();
      final displayName = name.text.trim().isEmpty ? 'Guest' : name.text.trim();
      await profile.setDisplayName(displayName);
      final isHost = room.hostUserId == id;
      await profile.rememberRoom(room, createdByMe: isHost);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomScreen(room: room, userId: id, displayName: displayName, isHost: isHost)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Join room')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 20), const Text('Join your people', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8), const Text('Enter the room code shared by the host.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 28), TextField(controller: name, decoration: const InputDecoration(labelText: 'Your display name', prefixIcon: Icon(Icons.person_rounded))),
        const SizedBox(height: 14), TextField(controller: code, textCapitalization: TextCapitalization.characters, style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.w800, fontSize: 22), decoration: const InputDecoration(labelText: 'Room code', prefixIcon: Icon(Icons.grid_view_rounded), hintText: 'AB12CD')),
        const SizedBox(height: 22), FilledButton.icon(onPressed: loading ? null : join, icon: const Icon(Icons.login_rounded), label: const Text('Join room'), style: FilledButton.styleFrom(backgroundColor: AppColors.indigo, padding: const EdgeInsets.symmetric(vertical: 18))),
      ]),
    ),
  );
}
