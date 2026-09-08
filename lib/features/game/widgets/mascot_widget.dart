import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MascotMood { idle, happy, sad, excited }

/// קמעון המשחק - דמות מאוירת (אריח-קסם עם כובע קוסם), נוצרה בסגנון האייקון
/// ואריחי הלוח כדי ליצור זהות ויזואלית עקבית בכל המשחק. יש שתי תמונות בסיס
/// (שמח/עצוב) עם אנימציות שונות לפי [MascotMood], כדי לתת פידבק רגשי מבלי
/// לדרוש קובצי אנימציה חיצוניים (Rive/Lottie).
class MascotWidget extends StatelessWidget {
  final MascotMood mood;
  final double size;

  const MascotWidget({super.key, this.mood = MascotMood.idle, this.size = 96});

  String get _assetPath {
    switch (mood) {
      case MascotMood.sad:
        return 'assets/mascot/mascot_sad.png';
      case MascotMood.idle:
      case MascotMood.happy:
      case MascotMood.excited:
        return 'assets/mascot/mascot_happy.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget face = Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    switch (mood) {
      case MascotMood.idle:
        return face
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 1200.ms, curve: Curves.easeInOut);
      case MascotMood.happy:
      case MascotMood.excited:
        return face
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.12, duration: 350.ms, curve: Curves.easeOut)
            .then()
            .shake(hz: 2, curve: Curves.easeInOut);
      case MascotMood.sad:
        return face.animate().moveY(begin: -4, end: 4, duration: 500.ms);
    }
  }
}
