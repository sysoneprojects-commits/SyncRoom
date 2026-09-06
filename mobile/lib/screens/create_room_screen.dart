import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/room.dart';
import '../services/api_service.dart';
import '../services/media_service.dart';
import '../services/profile_store.dart';
import 'room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final MediaSourceType? initialSource;
  final String? initialLocalSource;
  const CreateRoomScreen({super.key, this.initialSource, this.initialLocalSource});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

String _displayLocal(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null && uri.scheme == 'content') return uri.pathSegments.isEmpty ? 'Device video' : uri.pathSegments.last;
  return value.split('/').last;
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final roomName = TextEditingController(text: 'Movie Night');
  final hostName = TextEditingController(text: 'Guest');
  final sourceValue = TextEditingController();
  final api = ApiService();
  final media = MediaService();
  final profile = ProfileStore();
  late MediaSourceType source;
  bool loading = false;
  String? localPath;

  @override
  void initState() {
    super.initState();
    source = widget.initialLocalSource != null ? MediaSourceType.local : (widget.initialSource ?? MediaSourceType.youtube);
    if (widget.initialLocalSource != null) { localPath = widget.initialLocalSource; sourceValue.text = widget.initialLocalSource!; }
    profile.displayName().then((value) { if (mounted) setState(() => hostName.text = value); });
  }

  @override
  void dispose() {
    roomName.dispose(); hostName.dispose(); sourceValue.dispose(); super.dispose();
  }

  Future<void> chooseLocal() async {
    final file = await media.pickLocalVideo();
    if (file != null) setState(() { localPath = file.path; sourceValue.text = file.path; });
  }

  Future<void> create() async {
    if (source == MediaSourceType.youtube && sourceValue.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YouTube link kiriting'))); return;
    }
    if (source == MediaSourceType.local && localPath == null) {
      await chooseLocal(); if (localPath == null) return;
    }
    setState(() => loading = true);
    final userId = await profile.userId();
    final displayName = hostName.text.trim().isEmpty ? 'Guest' : hostName.text.trim();
    await profile.setDisplayName(displayName);
    final String? publicSourceValue = switch (source) {
      MediaSourceType.youtube => sourceValue.text.trim().isEmpty ? null : sourceValue.text.trim(),
      MediaSourceType.local => localPath == null ? null : _displayLocal(localPath!),
      MediaSourceType.screenShare => null,
    };
    try {
      final room = await api.createRoom(name: roomName.text.trim(), hostName: displayName, hostUserId: userId, sourceType: source, sourceValue: publicSourceValue);
      await profile.rememberRoom(room, createdByMe: true, localSource: localPath);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomScreen(room: room, userId: userId, displayName: displayName, isHost: true, localSource: localPath)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create room')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Set up your watch room', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Pick the source and invite people after the room opens.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 26),
        TextField(controller: roomName, decoration: const InputDecoration(labelText: 'Room name', prefixIcon: Icon(Icons.movie_rounded))),
        const SizedBox(height: 14),
        TextField(controller: hostName, decoration: const InputDecoration(labelText: 'Your display name', prefixIcon: Icon(Icons.person_rounded))),
        const SizedBox(height: 24),
        const Text('SOURCE', style: TextStyle(letterSpacing: 2.4, color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 10),
        ...MediaSourceType.values.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RadioListTile<MediaSourceType>(
            value: s, groupValue: source, onChanged: (v) => setState(() => source = v!),
            tileColor: AppColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
            title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s == MediaSourceType.youtube ? 'Synchronized official YouTube player' : s == MediaSourceType.local ? 'Choose a video stored on this device' : 'Share this app / screen in real time', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        )),
        if (source == MediaSourceType.youtube) ...[
          const SizedBox(height: 4), TextField(controller: sourceValue, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'YouTube URL', prefixIcon: Icon(Icons.link_rounded), hintText: 'https://youtube.com/watch?v=...')),
        ],
        if (source == MediaSourceType.local) ...[
          const SizedBox(height: 4), OutlinedButton.icon(onPressed: chooseLocal, icon: const Icon(Icons.folder_open_rounded), label: Text(localPath == null ? 'Choose video from device' : 'Selected: ${_displayLocal(localPath!)}'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18))),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(onPressed: loading ? null : create, icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded), label: const Text('Create room'), style: FilledButton.styleFrom(backgroundColor: AppColors.indigo, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
      ]),
    );
  }
}
