import 'package:flutter/material.dart';

import '../../game_engine/rewards/rarity.dart';

/// השפה החזותית של דרגות הנדירות. אותם צבעים בכל מקום (תיבה, תגית, גלגל,
/// זיקוקים) - כך שאחרי פעם-פעמיים השחקן/ית מזהים "סגול = אפי!" עוד לפני
/// שהטקסט מופיע.
class RarityStyle {
  final Color base;
  final Color light;
  final Color dark;
  final Color glow;

  /// צבעי החלקיקים/הזיקוקים.
  final List<Color> particles;

  /// עוצמת החגיגה 0..1 (גודל הזוהר, כמות חלקיקים, רעידה).
  final double intensity;

  /// כמה זיקוקים נורים בפתיחה.
  final int fireworks;

  const RarityStyle({
    required this.base,
    required this.light,
    required this.dark,
    required this.glow,
    required this.particles,
    required this.intensity,
    required this.fireworks,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, base, dark],
        stops: const [0, 0.5, 1],
      );

  static RarityStyle of(Rarity rarity) => _styles[rarity.index];

  static const _styles = [
    // רגיל - תכלת-אפור קריר
    RarityStyle(
      base: Color(0xFF8FA3C8),
      light: Color(0xFFE6EEFB),
      dark: Color(0xFF55678E),
      glow: Color(0xFFBFD3F5),
      particles: [Color(0xFFFFFFFF), Color(0xFFBFD3F5), Color(0xFF8FA3C8)],
      intensity: 0.2,
      fireworks: 0,
    ),
    // לא שכיח - ירוק
    RarityStyle(
      base: Color(0xFF2FD27A),
      light: Color(0xFFB8F7CF),
      dark: Color(0xFF0E8F4B),
      glow: Color(0xFF6CFFAA),
      particles: [Color(0xFFFFFFFF), Color(0xFF6CFFAA), Color(0xFF2FD27A), Color(0xFFFFE066)],
      intensity: 0.4,
      fireworks: 1,
    ),
    // נדיר - כחול
    RarityStyle(
      base: Color(0xFF2F86FF),
      light: Color(0xFFB5D6FF),
      dark: Color(0xFF1546C8),
      glow: Color(0xFF5EB0FF),
      particles: [Color(0xFFFFFFFF), Color(0xFF8CC8FF), Color(0xFF2F86FF), Color(0xFF6CF3FF)],
      intensity: 0.6,
      fireworks: 3,
    ),
    // אפי - סגול
    RarityStyle(
      base: Color(0xFFB04DFF),
      light: Color(0xFFEBC8FF),
      dark: Color(0xFF6A16C9),
      glow: Color(0xFFD27CFF),
      particles: [Color(0xFFFFFFFF), Color(0xFFE3A6FF), Color(0xFFB04DFF), Color(0xFFFF6BD5), Color(0xFF7C8CFF)],
      intensity: 0.82,
      fireworks: 6,
    ),
    // אגדי - זהב
    RarityStyle(
      base: Color(0xFFFFB800),
      light: Color(0xFFFFF4B5),
      dark: Color(0xFFD9690B),
      glow: Color(0xFFFFD84D),
      particles: [
        Color(0xFFFFFFFF),
        Color(0xFFFFE066),
        Color(0xFFFFB800),
        Color(0xFFFF7A45),
        Color(0xFFFF4FA3),
        Color(0xFF5EE0FF),
        Color(0xFF7CFF8C),
      ],
      intensity: 1,
      fireworks: 12,
    ),
  ];
}
