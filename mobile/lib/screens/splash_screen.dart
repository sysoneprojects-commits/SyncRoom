import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/syncroom_logo.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(.65, -.2),
            radius: 1.2,
            colors: [Color(0x332F6BFF), AppColors.bg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SyncRoomLogo(size: 104),
              SizedBox(height: 24),
              Text('SyncRoom', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('WATCH TOGETHER', style: TextStyle(letterSpacing: 5, color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
