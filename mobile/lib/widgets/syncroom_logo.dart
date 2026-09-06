import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class SyncRoomLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const SyncRoomLogo({super.key, this.size = 64, this.showText = false});

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SyncRoomMarkPainter()),
    );
    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Sync', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Room', style: TextStyle(color: AppColors.indigo)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncRoomMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B1733), Color(0xFF0A0C1A), Color(0xFF24114F)],
      ).createShader(rect);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(size.width * .26));
    canvas.drawRRect(r, bg);

    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x55466BFF), Colors.transparent],
      ).createShader(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * .7));
    canvas.drawRRect(r, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = AppColors.accentGradient.createShader(rect);

    final p = Path();
    p.moveTo(size.width * .24, size.height * .66);
    p.lineTo(size.width * .24, size.height * .39);
    p.lineTo(size.width * .50, size.height * .23);
    p.lineTo(size.width * .76, size.height * .39);
    p.lineTo(size.width * .76, size.height * .66);
    canvas.drawPath(p, stroke);

    final play = Path();
    play.moveTo(size.width * .45, size.height * .40);
    play.lineTo(size.width * .45, size.height * .58);
    play.lineTo(size.width * .61, size.height * .49);
    play.close();
    canvas.drawPath(play, Paint()..shader = AppColors.accentGradient.createShader(rect));

    final peoplePaint = Paint()..shader = AppColors.accentGradient.createShader(rect);
    for (final x in [.34, .50, .66]) {
      canvas.drawCircle(Offset(size.width * x, size.height * .69), size.width * .055, peoplePaint);
    }
    final body = Path();
    for (final x in [.34, .50, .66]) {
      final cx = size.width * x;
      final top = size.height * .76;
      final w = size.width * .12;
      body.addArc(Rect.fromCenter(center: Offset(cx, top), width: w, height: w * .75), math.pi, math.pi);
    }
    canvas.drawPath(body, peoplePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
