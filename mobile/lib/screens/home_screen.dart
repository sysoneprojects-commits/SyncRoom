import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/room.dart';
import '../services/incoming_media_service.dart';
import '../widgets/syncroom_logo.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'rooms_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  StreamSubscription<String>? incomingMediaSub;

  @override
  void initState() {
    super.initState();
    incomingMediaSub = IncomingMediaService.instance.media.listen((source) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateRoomScreen(initialSource: MediaSourceType.local, initialLocalSource: source),
      ));
    });
    IncomingMediaService.instance.initialize();
  }

  @override
  void dispose() {
    incomingMediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: const [_HomeBody(), RoomsScreen(), SearchScreen(), ProfileScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF060B18),
        indicatorColor: const Color(0x33466BFF),
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(children: [const SyncRoomLogo(size: 46, showText: true), const Spacer(), IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new notifications'))), icon: const Icon(Icons.notifications_none_rounded))]),
        const SizedBox(height: 34),
        const Text('GOOD EVENING', style: TextStyle(color: AppColors.muted, letterSpacing: 3, fontSize: 11)),
        const SizedBox(height: 8),
        RichText(text: const TextSpan(style: TextStyle(fontSize: 39, fontWeight: FontWeight.w900, height: 1.08), children: [TextSpan(text: 'Ready to\nwatch '), TextSpan(text: 'together?', style: TextStyle(color: AppColors.indigo))])),
        const SizedBox(height: 10),
        const Text('Same stories. A brighter room.', style: TextStyle(color: AppColors.muted, fontSize: 16)),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0A2145), Color(0xFF10163B), Color(0xFF241145)]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Start a room\nin seconds', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Watch, sync, and share with the people who matter.', style: TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _GradientButton(label: 'Create room', icon: Icons.add_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen())))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinRoomScreen())), icon: const Icon(Icons.grid_view_rounded), label: const Text('Join with code'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))))),
            ]),
          ]),
        ),
        const SizedBox(height: 28),
        const Text('ADD CONTENT', style: TextStyle(color: AppColors.muted, letterSpacing: 3, fontSize: 11)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SourceCard(title: 'YouTube Link', subtitle: 'Paste a link', icon: Icons.play_circle_fill_rounded, color: Color(0xFFFF5E74), source: MediaSourceType.youtube)),
          const SizedBox(width: 10),
          Expanded(child: _SourceCard(title: 'From Device', subtitle: 'Local videos', icon: Icons.insert_drive_file_rounded, color: AppColors.blue, source: MediaSourceType.local)),
          const SizedBox(width: 10),
          Expanded(child: _SourceCard(title: 'Screen Share', subtitle: 'Share live', icon: Icons.screen_share_rounded, color: AppColors.violet, source: MediaSourceType.screenShare)),
        ]),
        const SizedBox(height: 28),
        Row(children: const [Expanded(child: Text('UPCOMING MOVIE NIGHTS', style: TextStyle(color: AppColors.muted, letterSpacing: 2.2, fontSize: 10))), Text('SEE ALL', style: TextStyle(color: AppColors.muted, fontSize: 11))]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 94, height: 72, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF14244D), Color(0xFF28143C)])), child: const Icon(Icons.movie_filter_rounded, size: 34, color: AppColors.indigo)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Interstellar Night', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), SizedBox(height: 8), Row(children: [Icon(Icons.calendar_month_rounded, size: 17, color: AppColors.indigo), SizedBox(width: 6), Text('Today 21:00', style: TextStyle(color: AppColors.muted))])])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(width: 8), Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)))]),
        ),
      );
}

class _SourceCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final MediaSourceType source;
  const _SourceCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.source});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen(initialSource: source))),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 32), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11))]),
        ),
      );
}
