import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/profile_store.dart';
import '../widgets/syncroom_logo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final store = ProfileStore();
  final name = TextEditingController();
  String userId = '';
  int rooms = 0;
  int hosted = 0;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { name.dispose(); super.dispose(); }

  Future<void> _load() async {
    final n = await store.displayName();
    final id = await store.userId();
    final history = await store.history();
    if (!mounted) return;
    setState(() { name.text = n; userId = id; rooms = history.length; hosted = history.where((e) => e['createdByMe'] == true).length; loading = false; });
  }

  Future<void> _save() async {
    await store.setDisplayName(name.text);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
    children: [
      const Text('Profile', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Your identity inside SyncRoom rooms.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B1D3D), Color(0xFF11162E), Color(0xFF24123C)]), borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          const SyncRoomLogo(size: 74),
          const SizedBox(height: 16),
          if (loading) const CircularProgressIndicator() else TextField(controller: name, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_rounded))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: loading ? null : _save, icon: const Icon(Icons.save_rounded), label: const Text('Save profile'), style: FilledButton.styleFrom(backgroundColor: AppColors.indigo)),
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: _Stat(value: '$rooms', label: 'Recent rooms')), const SizedBox(width: 12), Expanded(child: _Stat(value: '$hosted', label: 'Hosted'))]),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.fingerprint_rounded, color: AppColors.indigo), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Device identity', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(userId.isEmpty ? 'Loading…' : userId, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12))]))])),
    ],
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Column(children: [Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.indigo)), const SizedBox(height: 5), Text(label, style: const TextStyle(color: AppColors.muted))]));
}
