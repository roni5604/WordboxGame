import 'dart:math' as math;

import 'package:flutter/material.dart';

/// מנוע הדמויות של המשחק: כל דמות מצוירת בקוד (וקטורית - חדה בכל גודל,
/// בלי תמונות כבדות) בסגנון "מדבקה תלת-ממדית": ראש עם הצללה כדורית,
/// עיניים מבריקות, לחיים ורודות, רקע עגול עם גרדיאנט, ואביזרים.
///
/// שתי משפחות: [HumanLook] (ילדים וילדות בכל גווני העור ותסרוקות, ודמויות
/// קומיות - מלך, מלכה, ליצן, מלאך, שטן...) ו-[AnimalLook] (זני כלבים וחיות).

enum HairStyle {
  none,
  buzz,
  short,
  spiky,
  curly,
  afro,
  mohawk,
  long,
  ponytail,
  pigtails,
  bun,
  braids,
  bob,
  wavy,
  hijab,
}

enum Accessory {
  none,
  glasses,
  kippah,
  bow,
  flower,
  cap,
  crown,
  tiara,
  halo,
  horns,
  clown,
  pirate,
  wizardHat,
  witchHat,
  chefHat,
  ninja,
  astronaut,
  hero,
  vampire,
  headphones,
}

class HumanLook {
  final Color skin;
  final HairStyle hair;
  final Color hairColor;
  final bool lashes;
  final Accessory accessory;
  final Color outfit;
  final Color background;
  final bool freckles;

  const HumanLook({
    required this.skin,
    required this.hair,
    required this.hairColor,
    this.lashes = false,
    this.accessory = Accessory.none,
    this.outfit = const Color(0xFF4F8DFF),
    this.background = const Color(0xFFBFE3FF),
    this.freckles = false,
  });
}

enum AnimalKind {
  // כלבים
  pointer,
  boxer,
  chihuahua,
  husky,
  dalmatian,
  poodle,
  pug,
  golden,
  beagle,
  shiba,
  corgi,
  dachshund,
  labrador,
  // חיות
  cat,
  bunny,
  bear,
  panda,
  fox,
  lion,
  tiger,
  frog,
  owl,
  penguin,
  unicorn,
  monkey,
  koala,
  pig,
  cow,
  mouse,
  elephant,
  chick,
  robot,
  alien,
}

class AnimalLook {
  final AnimalKind kind;
  final Color fur;
  final Color accent;
  final Color background;

  const AnimalLook({required this.kind, required this.fur, required this.accent, required this.background});
}

/// גווני עור (מבהיר לכהה).
class SkinTones {
  SkinTones._();
  static const light = Color(0xFFFFE0C7);
  static const fair = Color(0xFFF7CDA8);
  static const tan = Color(0xFFE2A97E);
  static const olive = Color(0xFFC98E5E);
  static const brown = Color(0xFF9A643C);
  static const deep = Color(0xFF6B4226);
}

class CharacterPainter extends CustomPainter {
  final HumanLook? human;
  final AnimalLook? animal;

  const CharacterPainter.human(HumanLook look) : human = look, animal = null;

  const CharacterPainter.animal(AnimalLook look) : animal = look, human = null;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final bg = human?.background ?? animal!.background;
    _background(canvas, s, bg);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, s, s)));
    if (human != null) {
      _Human(canvas, s, human!).draw();
    } else {
      _Animal(canvas, s, animal!).draw();
    }
    canvas.restore();
    canvas.restore();
  }

  void _background(Canvas canvas, double s, Color bg) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          radius: 0.95,
          colors: [Color.lerp(bg, Colors.white, 0.45)!, bg, Color.lerp(bg, Colors.black, 0.18)!],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(CharacterPainter old) => old.human != human || old.animal != animal;
}

// ---------------------------------------------------------------- כלים

Paint _shade(Rect r, Color c, {double light = 0.35, double dark = 0.22}) => Paint()
  ..shader = RadialGradient(
    center: const Alignment(-0.35, -0.45),
    radius: 1.0,
    colors: [Color.lerp(c, Colors.white, light)!, c, Color.lerp(c, Colors.black, dark)!],
    stops: const [0, 0.55, 1],
  ).createShader(r);

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _darker(Color c, [double t = 0.25]) => Color.lerp(c, Colors.black, t)!;
Color _lighter(Color c, [double t = 0.3]) => Color.lerp(c, Colors.white, t)!;

void _eye(Canvas c, Offset p, double r, {Color iris = const Color(0xFF2B2440), bool lashes = false}) {
  c.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r * 2.3), _fill(iris));
  c.drawCircle(p.translate(-r * 0.32, -r * 0.45), r * 0.42, _fill(Colors.white));
  c.drawCircle(p.translate(r * 0.35, r * 0.4), r * 0.18, _fill(Colors.white.withValues(alpha: 0.8)));
  if (lashes) {
    final paint = _stroke(iris, r * 0.32);
    for (final a in const [-2.3, -1.9, -1.5]) {
      final dir = Offset(math.cos(a), math.sin(a));
      final side = p.dx < 0 ? -1 : 1;
      c.drawLine(p + Offset(dir.dx * side, dir.dy) * r * 1.05, p + Offset(dir.dx * side, dir.dy) * r * 1.6, paint);
    }
  }
}

void _star(Canvas c, Offset center, double r, Paint paint, {int points = 5, double inner = 0.45}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final rr = i.isEven ? r : r * inner;
    final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path..close(), paint);
}

// ---------------------------------------------------------------- בני אדם

class _Human {
  final Canvas c;
  final double s;
  final HumanLook l;

  _Human(this.c, this.s, this.l);

  Offset get head => Offset(s * 0.5, s * 0.47);
  double get r => s * 0.25;

  void draw() {
    _hairBack();
    _body();
    _neck();
    _ears();
    _face();
    _hairFront();
    _accessory();
  }

  void _body() {
    final outfit = l.accessory == Accessory.astronaut ? const Color(0xFFE9EDF5) : l.outfit;
    final rect = Rect.fromLTWH(s * 0.16, s * 0.76, s * 0.68, s * 0.42);
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.2)), _shade(rect, outfit));
    // צווארון / פרט בגד.
    switch (l.accessory) {
      case Accessory.vampire:
        final cape = Path()
          ..moveTo(s * 0.22, s * 0.78)
          ..lineTo(s * 0.36, s * 0.7)
          ..lineTo(s * 0.5, s * 0.84)
          ..lineTo(s * 0.64, s * 0.7)
          ..lineTo(s * 0.78, s * 0.78)
          ..close();
        c.drawPath(cape, _fill(const Color(0xFFB71C1C)));
      case Accessory.hero:
        _star(c, Offset(s * 0.5, s * 0.88), s * 0.07, _fill(const Color(0xFFFFD54F)));
      case Accessory.crown || Accessory.tiara:
        c.drawRect(Rect.fromLTWH(s * 0.16, s * 0.82, s * 0.68, s * 0.04), _fill(const Color(0xFFFFD54F)));
      default:
        final collar = Path()
          ..moveTo(s * 0.4, s * 0.77)
          ..lineTo(s * 0.5, s * 0.86)
          ..lineTo(s * 0.6, s * 0.77);
        c.drawPath(collar, _stroke(_lighter(outfit, 0.45), s * 0.025));
    }
  }

  void _neck() {
    final rect = Rect.fromCenter(center: Offset(s * 0.5, s * 0.73), width: s * 0.17, height: s * 0.12);
    c.drawRect(rect, _fill(_darker(l.skin, 0.12)));
  }

  void _ears() {
    if (l.hair == HairStyle.hijab || l.accessory == Accessory.astronaut || l.accessory == Accessory.ninja) return;
    for (final side in const [-1.0, 1.0]) {
      final p = head + Offset(side * r * 0.98, r * 0.08);
      final rect = Rect.fromCenter(center: p, width: r * 0.36, height: r * 0.46);
      c.drawOval(rect, _shade(rect, l.skin, light: 0.15));
    }
  }

  void _face() {
    final rect = Rect.fromCircle(center: head, radius: r);
    c.drawOval(rect, _shade(rect, l.skin, light: 0.28, dark: 0.12));
    if (l.accessory == Accessory.ninja) return _ninjaFace();
    final eyeY = head.dy + r * 0.08;
    final eyeR = r * 0.13;
    for (final side in const [-1.0, 1.0]) {
      final p = Offset(head.dx + side * r * 0.36, eyeY);
      if (l.accessory == Accessory.pirate && side > 0) {
        c.drawOval(Rect.fromCenter(center: p, width: eyeR * 3, height: eyeR * 2.6), _fill(const Color(0xFF1E1E1E)));
        c.drawLine(
          p + Offset(-eyeR * 1.6, -eyeR * 1.2),
          head + Offset(r * 0.95, -r * 0.5),
          _stroke(const Color(0xFF1E1E1E), r * 0.06),
        );
        continue;
      }
      _eye(c, p, eyeR, lashes: l.lashes);
      // גבות.
      c.drawLine(
        p + Offset(-eyeR * 1.1, -eyeR * 2.1),
        p + Offset(eyeR * 1.1, -eyeR * (l.accessory == Accessory.horns ? 1.6 : 2.3)),
        _stroke(_darker(l.hairColor == Colors.white ? l.skin : l.hairColor, 0.1), r * 0.06),
      );
    }
    // לחיים.
    for (final side in const [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(head.dx + side * r * 0.58, eyeY + r * 0.3), width: r * 0.32, height: r * 0.18),
        _fill(const Color(0xFFFF7A8A).withValues(alpha: 0.45)),
      );
    }
    if (l.freckles) {
      for (final side in const [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            Offset(head.dx + side * r * (0.42 + i * 0.09), eyeY + r * 0.24 + (i.isOdd ? r * 0.05 : 0)),
            r * 0.025,
            _fill(_darker(l.skin, 0.35)),
          );
        }
      }
    }
    // אף וחיוך.
    c.drawOval(
      Rect.fromCenter(center: Offset(head.dx, eyeY + r * 0.24), width: r * 0.14, height: r * 0.1),
      _fill(_darker(l.skin, 0.15)),
    );
    final smile = Path()
      ..moveTo(head.dx - r * 0.26, eyeY + r * 0.42)
      ..quadraticBezierTo(head.dx, eyeY + r * 0.72, head.dx + r * 0.26, eyeY + r * 0.42)
      ..close();
    c.drawPath(smile, _fill(const Color(0xFF7A1E2E)));
    c.drawOval(
      Rect.fromCenter(center: Offset(head.dx, eyeY + r * 0.6), width: r * 0.24, height: r * 0.1),
      _fill(const Color(0xFFFF6F7D)),
    );
    if (l.accessory == Accessory.vampire) {
      for (final side in const [-1.0, 1.0]) {
        final fang = Path()
          ..moveTo(head.dx + side * r * 0.16, eyeY + r * 0.45)
          ..lineTo(head.dx + side * r * 0.1, eyeY + r * 0.58)
          ..lineTo(head.dx + side * r * 0.05, eyeY + r * 0.46)
          ..close();
        c.drawPath(fang, _fill(Colors.white));
      }
    }
    if (l.accessory == Accessory.clown) {
      final nose = Rect.fromCircle(center: Offset(head.dx, eyeY + r * 0.24), radius: r * 0.16);
      c.drawOval(nose, _shade(nose, const Color(0xFFE53935)));
    }
  }

  void _ninjaFace() {
    final band = Rect.fromLTWH(head.dx - r, head.dy - r * 0.1, r * 2, r * 0.42);
    c.drawRect(band, _fill(_lighter(l.skin, 0.1)));
    for (final side in const [-1.0, 1.0]) {
      final p = Offset(head.dx + side * r * 0.36, head.dy + r * 0.1);
      _eye(c, p, r * 0.12);
      c.drawLine(
        p + Offset(-r * 0.16, -r * 0.2 + side * 0.0),
        p + Offset(r * 0.16, -r * 0.14),
        _stroke(const Color(0xFF1E1E1E), r * 0.06),
      );
    }
  }

  // שיער שמאחורי הראש (ארוך, צמות, חיג'אב).
  void _hairBack() {
    final hc = l.hairColor;
    final p = _shade(Rect.fromCircle(center: head, radius: r * 1.3), hc, light: 0.25);
    switch (l.hair) {
      case HairStyle.long || HairStyle.wavy:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx - r * 1.15, head.dy - r * 0.9, r * 2.3, r * 2.25),
            Radius.circular(r * 0.9),
          ),
          p,
        );
      case HairStyle.braids:
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 4; i++) {
            final o = Offset(head.dx + side * r * 1.0, head.dy + r * 0.35 + i * r * 0.32);
            c.drawCircle(o, r * 0.2, p);
          }
        }
      case HairStyle.hijab:
        final rect = Rect.fromLTWH(head.dx - r * 1.3, head.dy - r * 1.25, r * 2.6, r * 3.2);
        c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 1.25)), _shade(rect, hc, light: 0.25));
      case HairStyle.afro:
        final rect = Rect.fromCircle(center: head.translate(0, -r * 0.2), radius: r * 1.35);
        c.drawOval(rect, p);
      default:
        break;
    }
  }

  void _hairFront() {
    final hc = l.hairColor;
    final rect = Rect.fromCircle(center: head, radius: r * 1.1);
    final p = _shade(rect, hc, light: 0.3);
    final top = head.dy - r;
    switch (l.hair) {
      case HairStyle.none:
        break;
      case HairStyle.buzz:
        c.drawArc(
          Rect.fromCircle(center: head, radius: r * 1.02),
          math.pi * 1.05,
          math.pi * 0.9,
          false,
          _stroke(hc, r * 0.22),
        );
      case HairStyle.short ||
          HairStyle.long ||
          HairStyle.wavy ||
          HairStyle.ponytail ||
          HairStyle.pigtails ||
          HairStyle.bun ||
          HairStyle.braids ||
          HairStyle.bob:
        final cap = Path()
          ..moveTo(head.dx - r * 1.04, head.dy + r * 0.05)
          ..cubicTo(
            head.dx - r * 1.1,
            top - r * 0.35,
            head.dx + r * 1.1,
            top - r * 0.35,
            head.dx + r * 1.04,
            head.dy + r * 0.05,
          )
          ..quadraticBezierTo(head.dx + r * 0.6, head.dy - r * 0.62, head.dx + r * 0.1, head.dy - r * 0.5)
          ..quadraticBezierTo(head.dx - r * 0.4, head.dy - r * 0.62, head.dx - r * 1.04, head.dy + r * 0.05)
          ..close();
        c.drawPath(cap, p);
        if (l.hair == HairStyle.ponytail) {
          final tail = Rect.fromCenter(
            center: Offset(head.dx + r * 1.05, head.dy - r * 0.55),
            width: r * 0.6,
            height: r * 1.1,
          );
          c.drawOval(tail, p);
        } else if (l.hair == HairStyle.pigtails) {
          for (final side in const [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(
                center: Offset(head.dx + side * r * 1.15, head.dy - r * 0.2),
                width: r * 0.6,
                height: r * 0.8,
              ),
              p,
            );
          }
        } else if (l.hair == HairStyle.bun) {
          c.drawCircle(Offset(head.dx, top - r * 0.15), r * 0.38, p);
        } else if (l.hair == HairStyle.bob) {
          for (final side in const [-1.0, 1.0]) {
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(head.dx + (side < 0 ? -r * 1.15 : r * 0.78), head.dy - r * 0.4, r * 0.37, r * 1.05),
                Radius.circular(r * 0.2),
              ),
              p,
            );
          }
        }
      case HairStyle.spiky:
        final path = Path()..moveTo(head.dx - r * 1.02, head.dy - r * 0.1);
        for (var i = 0; i <= 6; i++) {
          final x = head.dx - r + i * r / 3;
          path.lineTo(x, top - r * (i.isEven ? 0.35 : 0.0) + (i == 0 || i == 6 ? r * 0.5 : 0));
        }
        path
          ..lineTo(head.dx + r * 1.02, head.dy - r * 0.1)
          ..quadraticBezierTo(head.dx, head.dy - r * 0.55, head.dx - r * 1.02, head.dy - r * 0.1);
        c.drawPath(path..close(), p);
      case HairStyle.curly:
        for (var i = 0; i < 9; i++) {
          final a = math.pi + i * math.pi / 8;
          c.drawCircle(head + Offset(math.cos(a) * r * 0.92, math.sin(a) * r * 0.85), r * 0.3, p);
        }
      case HairStyle.afro:
        for (var i = 0; i < 7; i++) {
          final a = math.pi * 1.05 + i * math.pi * 0.9 / 6;
          c.drawCircle(head + Offset(math.cos(a) * r * 0.75, math.sin(a) * r * 0.7), r * 0.32, p);
        }
      case HairStyle.mohawk:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx - r * 0.18, top - r * 0.5, r * 0.36, r * 0.9),
            Radius.circular(r * 0.18),
          ),
          p,
        );
      case HairStyle.hijab:
        // מסגרת הפנים של החיג'אב.
        c.drawArc(
          Rect.fromCircle(center: head, radius: r * 1.05),
          math.pi * 0.9,
          math.pi * 1.2,
          false,
          _stroke(_darker(hc, 0.1), r * 0.22),
        );
    }
  }

  void _accessory() {
    final top = head.dy - r;
    switch (l.accessory) {
      case Accessory.none || Accessory.ninja || Accessory.vampire || Accessory.hero:
        if (l.accessory == Accessory.ninja) {
          c.drawRect(
            Rect.fromLTWH(head.dx - r * 1.05, top - r * 0.05, r * 2.1, r * 0.95),
            _fill(const Color(0xFF263238)),
          );
          c.drawRect(
            Rect.fromLTWH(head.dx - r * 1.05, head.dy + r * 0.3, r * 2.1, r * 0.75),
            _fill(const Color(0xFF263238)),
          );
          c.drawRect(
            Rect.fromLTWH(head.dx - r * 1.05, top + r * 0.55, r * 2.1, r * 0.12),
            _fill(const Color(0xFFE53935)),
          );
        }
        if (l.accessory == Accessory.hero) {
          final mask = Rect.fromCenter(center: Offset(head.dx, head.dy + r * 0.06), width: r * 1.5, height: r * 0.42);
          c.drawRRect(
            RRect.fromRectAndRadius(mask, Radius.circular(r * 0.2)),
            _fill(const Color(0xFFE53935).withValues(alpha: 0.85)),
          );
          for (final side in const [-1.0, 1.0]) {
            _eye(c, Offset(head.dx + side * r * 0.36, head.dy + r * 0.08), r * 0.11);
          }
        }
        if (l.accessory == Accessory.vampire) {
          final widow = Path()
            ..moveTo(head.dx - r * 0.9, head.dy - r * 0.45)
            ..quadraticBezierTo(head.dx, head.dy - r * 0.9, head.dx, head.dy - r * 0.35)
            ..quadraticBezierTo(head.dx, head.dy - r * 0.9, head.dx + r * 0.9, head.dy - r * 0.45)
            ..lineTo(head.dx + r, top)
            ..lineTo(head.dx - r, top)
            ..close();
          c.drawPath(widow, _fill(const Color(0xFF1B1B2F)));
        }
      case Accessory.glasses:
        final p = _stroke(const Color(0xFF2B2440), r * 0.07);
        for (final side in const [-1.0, 1.0]) {
          c.drawCircle(Offset(head.dx + side * r * 0.36, head.dy + r * 0.08), r * 0.24, p);
        }
        c.drawLine(Offset(head.dx - r * 0.12, head.dy + r * 0.06), Offset(head.dx + r * 0.12, head.dy + r * 0.06), p);
      case Accessory.kippah:
        final rect = Rect.fromCenter(center: Offset(head.dx, top + r * 0.08), width: r * 0.95, height: r * 0.42);
        c.drawArc(rect, math.pi, math.pi, true, _shade(rect, const Color(0xFF1E5AA8)));
        c.drawArc(rect.deflate(r * 0.08), math.pi, math.pi, false, _stroke(Colors.white, r * 0.04));
      case Accessory.bow:
        final o = Offset(head.dx + r * 0.6, top + r * 0.12);
        for (final side in const [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + side * r * 0.42, o.dy - r * 0.25)
            ..lineTo(o.dx + side * r * 0.42, o.dy + r * 0.25)
            ..close();
          c.drawPath(path, _fill(const Color(0xFFFF4F8B)));
        }
        c.drawCircle(o, r * 0.12, _fill(const Color(0xFFD81B60)));
      case Accessory.flower:
        final o = Offset(head.dx - r * 0.65, top + r * 0.2);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * r * 0.17, r * 0.13, _fill(const Color(0xFFFF8FC0)));
        }
        c.drawCircle(o, r * 0.1, _fill(const Color(0xFFFFD54F)));
      case Accessory.cap:
        final rect = Rect.fromLTWH(head.dx - r * 1.02, top - r * 0.12, r * 2.04, r * 0.85);
        c.drawArc(rect, math.pi, math.pi, true, _shade(rect, l.outfit));
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx - r * 0.2, top + r * 0.22, r * 1.45, r * 0.2),
            Radius.circular(r * 0.1),
          ),
          _fill(_darker(l.outfit, 0.2)),
        );
      case Accessory.crown || Accessory.tiara:
        final big = l.accessory == Accessory.crown;
        final w = big ? r * 1.5 : r * 1.1;
        final h = big ? r * 0.6 : r * 0.38;
        final base = top + (big ? r * 0.08 : r * 0.12);
        final path = Path()..moveTo(head.dx - w / 2, base);
        const spikes = 5;
        for (var i = 0; i <= spikes * 2; i++) {
          final x = head.dx - w / 2 + i * w / (spikes * 2);
          path.lineTo(x, i.isEven ? base - h : base - h * 0.4);
        }
        path
          ..lineTo(head.dx + w / 2, base)
          ..close();
        final rect = Rect.fromLTWH(head.dx - w / 2, base - h, w, h);
        c.drawPath(path, _shade(rect, const Color(0xFFFFC93C), light: 0.5));
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            Offset(head.dx + (i - 1) * w * 0.3, base - h * 0.25),
            r * 0.06,
            _fill(const [Color(0xFFE53935), Color(0xFF42A5F5), Color(0xFF66BB6A)][i]),
          );
        }
      case Accessory.halo:
        final rect = Rect.fromCenter(center: Offset(head.dx, top - r * 0.22), width: r * 1.3, height: r * 0.32);
        c.drawOval(rect, _stroke(const Color(0xFFFFE082), r * 0.12));
        // כנפיים קטנות על הכתפיים.
        for (final side in const [-1.0, 1.0]) {
          final wing = Rect.fromCenter(
            center: Offset(head.dx + side * r * 1.45, s * 0.84),
            width: r * 0.8,
            height: r * 0.55,
          );
          c.drawOval(wing, _shade(wing, Colors.white, light: 0.1));
        }
      case Accessory.horns:
        for (final side in const [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(head.dx + side * r * 0.45, top + r * 0.2)
            ..quadraticBezierTo(head.dx + side * r * 0.85, top - r * 0.2, head.dx + side * r * 0.7, top - r * 0.5)
            ..quadraticBezierTo(head.dx + side * r * 0.62, top - r * 0.05, head.dx + side * r * 0.18, top + r * 0.12)
            ..close();
          c.drawPath(path, _fill(const Color(0xFFD32F2F)));
        }
      case Accessory.clown:
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            final colors = const [Color(0xFFFF5252), Color(0xFF40C4FF), Color(0xFFFFEB3B)];
            c.drawCircle(
              Offset(head.dx + side * r * (1.0 + i * 0.12), head.dy - r * 0.25 + i * r * 0.32),
              r * 0.3,
              _fill(colors[i]),
            );
          }
        }
        final hat = Path()
          ..moveTo(head.dx - r * 0.35, top + r * 0.08)
          ..lineTo(head.dx, top - r * 0.75)
          ..lineTo(head.dx + r * 0.35, top + r * 0.08)
          ..close();
        c.drawPath(hat, _fill(const Color(0xFF7C4DFF)));
        c.drawCircle(Offset(head.dx, top - r * 0.75), r * 0.12, _fill(const Color(0xFFFFEB3B)));
      case Accessory.pirate:
        final hat = Path()
          ..moveTo(head.dx - r * 1.25, top + r * 0.25)
          ..quadraticBezierTo(head.dx, top - r * 0.9, head.dx + r * 1.25, top + r * 0.25)
          ..quadraticBezierTo(head.dx, top + r * 0.05, head.dx - r * 1.25, top + r * 0.25)
          ..close();
        c.drawPath(hat, _fill(const Color(0xFF263238)));
        c.drawCircle(Offset(head.dx, top - r * 0.12), r * 0.13, _fill(Colors.white));
      case Accessory.wizardHat || Accessory.witchHat:
        final color = l.accessory == Accessory.wizardHat ? const Color(0xFF3949AB) : const Color(0xFF6A1B9A);
        c.drawOval(
          Rect.fromCenter(center: Offset(head.dx, top + r * 0.1), width: r * 2.5, height: r * 0.45),
          _fill(_darker(color, 0.15)),
        );
        final cone = Path()
          ..moveTo(head.dx - r * 0.75, top + r * 0.1)
          ..quadraticBezierTo(head.dx + r * 0.1, top - r * 0.6, head.dx + r * 0.55, top - r * 1.15)
          ..lineTo(head.dx + r * 0.75, top + r * 0.1)
          ..close();
        c.drawPath(cone, _shade(Rect.fromLTWH(head.dx - r, top - r * 1.2, r * 2, r * 1.3), color));
        _star(c, Offset(head.dx - r * 0.05, top - r * 0.3), r * 0.15, _fill(const Color(0xFFFFE082)));
      case Accessory.chefHat:
        for (final dx in const [-0.45, 0.0, 0.45]) {
          c.drawCircle(Offset(head.dx + dx * r, top - r * 0.25), r * 0.42, _fill(Colors.white));
        }
        c.drawRect(Rect.fromLTWH(head.dx - r * 0.8, top - r * 0.1, r * 1.6, r * 0.38), _fill(const Color(0xFFF2F2F2)));
      case Accessory.astronaut:
        final helmet = Rect.fromCircle(center: head, radius: r * 1.32);
        c.drawOval(helmet, _stroke(const Color(0xFFE9EDF5), r * 0.22));
        c.drawOval(helmet.deflate(r * 0.1), _fill(const Color(0xFF80DEEA).withValues(alpha: 0.18)));
        c.drawArc(
          helmet.deflate(r * 0.22),
          math.pi * 1.15,
          math.pi * 0.35,
          false,
          _stroke(Colors.white.withValues(alpha: 0.7), r * 0.08),
        );
      case Accessory.headphones:
        c.drawArc(
          Rect.fromCircle(center: head, radius: r * 1.12),
          math.pi * 1.05,
          math.pi * 0.9,
          false,
          _stroke(const Color(0xFF37474F), r * 0.14),
        );
        for (final side in const [-1.0, 1.0]) {
          final cup = Rect.fromCenter(
            center: Offset(head.dx + side * r * 1.05, head.dy + r * 0.05),
            width: r * 0.42,
            height: r * 0.62,
          );
          c.drawRRect(RRect.fromRectAndRadius(cup, Radius.circular(r * 0.18)), _shade(cup, l.outfit));
        }
    }
  }
}

// ---------------------------------------------------------------- חיות

class _Animal {
  final Canvas c;
  final double s;
  final AnimalLook a;

  _Animal(this.c, this.s, this.a);

  Offset get head => Offset(s * 0.5, s * 0.52);
  double get r => s * 0.3;

  void draw() {
    switch (a.kind) {
      case AnimalKind.owl:
        return _owl();
      case AnimalKind.penguin:
        return _penguin();
      case AnimalKind.chick:
        return _chick();
      case AnimalKind.frog:
        return _frog();
      case AnimalKind.robot:
        return _robot();
      case AnimalKind.alien:
        return _alien();
      default:
        break;
    }
    _body();
    _earsBack();
    if (a.kind == AnimalKind.lion) _mane();
    _headShape();
    _markings();
    _earsFront();
    _faceFeatures();
    _extras();
  }

  void _body() {
    final rect = Rect.fromLTWH(s * 0.2, s * 0.8, s * 0.6, s * 0.4);
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.2)), _shade(rect, a.fur));
    if (_isDog) {
      // קולר עם תליון.
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.33, s * 0.79, s * 0.34, s * 0.05), Radius.circular(s * 0.03)),
        _fill(const Color(0xFFE53935)),
      );
      c.drawCircle(Offset(s * 0.5, s * 0.86), s * 0.03, _fill(const Color(0xFFFFC93C)));
    }
  }

  bool get _isDog => a.kind.index <= AnimalKind.labrador.index;

  void _mane() {
    for (var i = 0; i < 14; i++) {
      final ang = i * math.pi * 2 / 14;
      c.drawCircle(head + Offset(math.cos(ang) * r * 1.0, math.sin(ang) * r * 0.95), r * 0.38, _fill(a.accent));
    }
  }

  void _headShape() {
    var rect = Rect.fromCircle(center: head, radius: r);
    if (a.kind == AnimalKind.chihuahua || a.kind == AnimalKind.cat || a.kind == AnimalKind.fox) {
      rect = Rect.fromCenter(center: head, width: r * 2.05, height: r * 1.85);
    } else if (a.kind == AnimalKind.boxer || a.kind == AnimalKind.pug || a.kind == AnimalKind.bear) {
      rect = Rect.fromCenter(center: head, width: r * 2.1, height: r * 1.95);
    }
    c.drawOval(rect, _shade(rect, a.fur, light: 0.3, dark: 0.18));
  }

  void _markings() {
    final accent = _fill(a.accent);
    switch (a.kind) {
      case AnimalKind.dalmatian:
        final rnd = math.Random(4);
        for (var i = 0; i < 7; i++) {
          final ang = rnd.nextDouble() * math.pi * 2;
          final d = r * (0.45 + rnd.nextDouble() * 0.45);
          c.drawCircle(
            head + Offset(math.cos(ang) * d, math.sin(ang) * d * 0.9),
            r * (0.08 + rnd.nextDouble() * 0.06),
            accent,
          );
        }
      case AnimalKind.husky:
        final mask = Path()
          ..moveTo(head.dx, head.dy - r * 0.6)
          ..quadraticBezierTo(head.dx - r * 0.9, head.dy - r * 0.2, head.dx - r * 0.7, head.dy + r * 0.8)
          ..quadraticBezierTo(head.dx, head.dy + r * 1.05, head.dx + r * 0.7, head.dy + r * 0.8)
          ..quadraticBezierTo(head.dx + r * 0.9, head.dy - r * 0.2, head.dx, head.dy - r * 0.6)
          ..close();
        c.drawPath(mask, accent);
      case AnimalKind.panda:
        for (final side in const [-1.0, 1.0]) {
          c.save();
          c.translate(head.dx + side * r * 0.4, head.dy - r * 0.02);
          c.rotate(side * 0.5);
          c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.48, height: r * 0.62), accent);
          c.restore();
        }
      case AnimalKind.tiger:
        final stripe = _stroke(a.accent, r * 0.1);
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            c.drawLine(
              head + Offset(side * r * 0.98, -r * 0.3 + i * r * 0.25),
              head + Offset(side * r * 0.66, -r * 0.24 + i * r * 0.25),
              stripe,
            );
          }
        }
        for (var i = 0; i < 3; i++) {
          c.drawLine(
            head + Offset(-r * 0.2 + i * r * 0.2, -r * 0.98),
            head + Offset(-r * 0.2 + i * r * 0.2, -r * 0.7),
            stripe,
          );
        }
      case AnimalKind.beagle ||
          AnimalKind.corgi ||
          AnimalKind.shiba ||
          AnimalKind.boxer ||
          AnimalKind.fox ||
          AnimalKind.cow ||
          AnimalKind.pointer:
        // "בלייז" - פס בהיר במרכז הפנים ולוע בהיר.
        final blaze = Path()
          ..moveTo(head.dx - r * 0.12, head.dy - r * 0.85)
          ..lineTo(head.dx + r * 0.12, head.dy - r * 0.85)
          ..lineTo(head.dx + r * 0.5, head.dy + r * 0.9)
          ..lineTo(head.dx - r * 0.5, head.dy + r * 0.9)
          ..close();
        if (a.kind != AnimalKind.pointer && a.kind != AnimalKind.cow) c.drawPath(blaze, accent);
        if (a.kind == AnimalKind.cow) {
          c.drawOval(
            Rect.fromCenter(center: head + Offset(r * 0.45, -r * 0.45), width: r * 0.6, height: r * 0.45),
            _fill(const Color(0xFF3E2723)),
          );
        }
      default:
        break;
    }
  }

  void _earsBack() {
    final ear = _shade(Rect.fromCircle(center: head, radius: r * 1.4), _darker(a.fur, 0.08));
    final inner = _fill(_lighter(a.accent == a.fur ? a.fur : a.accent, 0.1));
    switch (a.kind) {
      case AnimalKind.bunny:
        for (final side in const [-1.0, 1.0]) {
          final rect = Rect.fromCenter(
            center: head + Offset(side * r * 0.42, -r * 1.25),
            width: r * 0.5,
            height: r * 1.3,
          );
          c.drawOval(rect, ear);
          c.drawOval(rect.deflate(r * 0.1), _fill(const Color(0xFFFFB3C7)));
        }
      case AnimalKind.elephant:
        for (final side in const [-1.0, 1.0]) {
          final rect = Rect.fromCenter(center: head + Offset(side * r * 0.95, 0), width: r * 1.1, height: r * 1.3);
          c.drawOval(rect, ear);
          c.drawOval(rect.deflate(r * 0.15), _fill(const Color(0xFFF8BBD0).withValues(alpha: 0.7)));
        }
      case AnimalKind.monkey:
        for (final side in const [-1.0, 1.0]) {
          final rect = Rect.fromCircle(center: head + Offset(side * r * 0.98, 0), radius: r * 0.32);
          c.drawOval(rect, ear);
          c.drawOval(rect.deflate(r * 0.08), inner);
        }
      case AnimalKind.koala || AnimalKind.mouse:
        for (final side in const [-1.0, 1.0]) {
          final rect = Rect.fromCircle(center: head + Offset(side * r * 0.85, -r * 0.62), radius: r * 0.48);
          c.drawOval(rect, ear);
          c.drawOval(rect.deflate(r * 0.12), _fill(const Color(0xFFFFCDD2)));
        }
      default:
        break;
    }
  }

  void _earsFront() {
    final earColor = switch (a.kind) {
      AnimalKind.beagle || AnimalKind.dalmatian || AnimalKind.pointer => a.accent,
      AnimalKind.panda => a.accent,
      _ => _darker(a.fur, 0.1),
    };
    final ear = _shade(Rect.fromCircle(center: head, radius: r * 1.3), earColor);
    final inner = _fill(const Color(0xFFFFB3C7));
    Path triangle(double side, double w, double h, double dx, double dy) => Path()
      ..moveTo(head.dx + side * (dx - w / 2) * r, head.dy + dy * r)
      ..lineTo(head.dx + side * dx * r, head.dy + (dy - h) * r)
      ..lineTo(head.dx + side * (dx + w / 2) * r, head.dy + dy * r)
      ..close();
    for (final side in const [-1.0, 1.0]) {
      switch (a.kind) {
        case AnimalKind.cat ||
            AnimalKind.fox ||
            AnimalKind.husky ||
            AnimalKind.shiba ||
            AnimalKind.corgi ||
            AnimalKind.tiger:
          final big = a.kind == AnimalKind.corgi ? 1.2 : 1.0;
          c.drawPath(triangle(side, 0.6 * big, 0.75 * big, 0.6, -0.55), ear);
          c.drawPath(triangle(side, 0.32 * big, 0.45 * big, 0.6, -0.6), inner);
        case AnimalKind.chihuahua:
          c.drawPath(triangle(side, 0.75, 1.05, 0.78, -0.35), ear);
          c.drawPath(triangle(side, 0.42, 0.7, 0.78, -0.42), inner);
        case AnimalKind.boxer || AnimalKind.pug:
          final rect = Rect.fromCenter(
            center: head + Offset(side * r * 0.78, -r * 0.7),
            width: r * 0.5,
            height: r * 0.42,
          );
          c.drawOval(rect, ear);
        case AnimalKind.beagle ||
            AnimalKind.dalmatian ||
            AnimalKind.golden ||
            AnimalKind.labrador ||
            AnimalKind.dachshund ||
            AnimalKind.pointer ||
            AnimalKind.poodle:
          final long = a.kind == AnimalKind.beagle || a.kind == AnimalKind.dachshund ? 1.25 : 1.0;
          c.save();
          c.translate(head.dx + side * r * 0.92, head.dy - r * 0.15);
          c.rotate(side * 0.18);
          final rect = Rect.fromCenter(center: Offset(0, r * 0.35 * long), width: r * 0.55, height: r * 1.05 * long);
          if (a.kind == AnimalKind.poodle) {
            for (var i = 0; i < 3; i++) {
              c.drawCircle(Offset(0, r * 0.1 + i * r * 0.32), r * 0.28, _shade(rect, a.fur, light: 0.4));
            }
          } else {
            c.drawOval(rect, ear);
          }
          c.restore();
        case AnimalKind.bear || AnimalKind.panda || AnimalKind.lion:
          final rect = Rect.fromCircle(center: head + Offset(side * r * 0.72, -r * 0.72), radius: r * 0.3);
          c.drawOval(rect, ear);
          if (a.kind != AnimalKind.panda) c.drawOval(rect.deflate(r * 0.09), _fill(_lighter(a.fur, 0.35)));
        case AnimalKind.pig:
          c.drawPath(triangle(side, 0.45, 0.45, 0.62, -0.62), _fill(_darker(a.fur, 0.1)));
        case AnimalKind.cow:
          c.save();
          c.translate(head.dx + side * r * 1.0, head.dy - r * 0.38);
          c.rotate(side * -0.4);
          c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.62, height: r * 0.3), ear);
          c.restore();
          // קרניים.
          c.drawLine(
            head + Offset(side * r * 0.42, -r * 0.82),
            head + Offset(side * r * 0.6, -r * 1.12),
            _stroke(const Color(0xFFFFF3E0), r * 0.13),
          );
        case AnimalKind.unicorn:
          c.drawPath(triangle(side, 0.45, 0.6, 0.62, -0.62), ear);
        default:
          break;
      }
    }
    if (a.kind == AnimalKind.poodle) {
      // פונפון על הראש.
      for (var i = 0; i < 5; i++) {
        c.drawCircle(
          head + Offset((i - 2) * r * 0.22, -r * 0.92 - (i == 2 ? r * 0.12 : 0)),
          r * 0.26,
          _shade(Rect.fromCircle(center: head, radius: r), a.fur, light: 0.45),
        );
      }
    }
  }

  void _faceFeatures() {
    final eyeY = head.dy - r * 0.05;
    final eyeR = r * 0.12;
    final wide = a.kind == AnimalKind.pug || a.kind == AnimalKind.chihuahua ? 0.42 : 0.36;
    final iris = a.kind == AnimalKind.husky ? const Color(0xFF1E88E5) : const Color(0xFF2B2440);
    for (final side in const [-1.0, 1.0]) {
      _eye(c, Offset(head.dx + side * r * wide, eyeY), eyeR * (a.kind == AnimalKind.chihuahua ? 1.25 : 1), iris: iris);
    }
    // לוע.
    final snoutColor = switch (a.kind) {
      AnimalKind.pig => _lighter(a.fur, 0.15),
      AnimalKind.boxer || AnimalKind.pug => _darker(a.accent, 0.0),
      AnimalKind.monkey || AnimalKind.bear || AnimalKind.koala || AnimalKind.lion || AnimalKind.cow => a.accent,
      _ => _lighter(a.fur, 0.55),
    };
    final snoutRect = Rect.fromCenter(
      center: Offset(head.dx, head.dy + r * 0.38),
      width: r * (a.kind == AnimalKind.pig || a.kind == AnimalKind.cow ? 0.9 : 0.8),
      height: r * (a.kind == AnimalKind.pig ? 0.55 : 0.52),
    );
    if (a.kind != AnimalKind.elephant) c.drawOval(snoutRect, _shade(snoutRect, snoutColor, light: 0.3, dark: 0.08));
    switch (a.kind) {
      case AnimalKind.pig:
        for (final side in const [-1.0, 1.0]) {
          c.drawOval(
            Rect.fromCenter(center: snoutRect.center + Offset(side * r * 0.14, 0), width: r * 0.12, height: r * 0.18),
            _fill(_darker(a.fur, 0.35)),
          );
        }
      case AnimalKind.cow:
        for (final side in const [-1.0, 1.0]) {
          c.drawCircle(snoutRect.center + Offset(side * r * 0.18, 0), r * 0.06, _fill(_darker(a.accent, 0.4)));
        }
      case AnimalKind.elephant:
        final trunk = Path()
          ..moveTo(head.dx - r * 0.2, head.dy + r * 0.15)
          ..quadraticBezierTo(head.dx - r * 0.25, head.dy + r * 0.9, head.dx + r * 0.25, head.dy + r * 1.0)
          ..lineTo(head.dx + r * 0.3, head.dy + r * 0.82)
          ..quadraticBezierTo(head.dx + r * 0.1, head.dy + r * 0.7, head.dx + r * 0.2, head.dy + r * 0.15)
          ..close();
        c.drawPath(trunk, _shade(Rect.fromCircle(center: head, radius: r), a.fur));
      default:
        // אף משולש-מעוגל + פה.
        final nose = Rect.fromCenter(center: Offset(head.dx, head.dy + r * 0.26), width: r * 0.3, height: r * 0.2);
        c.drawRRect(
          RRect.fromRectAndRadius(nose, Radius.circular(r * 0.1)),
          _fill(a.kind == AnimalKind.koala ? const Color(0xFF424242) : const Color(0xFF3B2A2A)),
        );
        c.drawCircle(nose.center.translate(-r * 0.05, -r * 0.04), r * 0.04, _fill(Colors.white.withValues(alpha: 0.7)));
        final mouth = Path()
          ..moveTo(head.dx - r * 0.18, head.dy + r * 0.45)
          ..quadraticBezierTo(head.dx - r * 0.08, head.dy + r * 0.55, head.dx, head.dy + r * 0.42)
          ..quadraticBezierTo(head.dx + r * 0.08, head.dy + r * 0.55, head.dx + r * 0.18, head.dy + r * 0.45);
        c.drawPath(mouth, _stroke(const Color(0xFF3B2A2A), r * 0.05));
        if (_isDog) {
          // לשון.
          c.drawOval(
            Rect.fromCenter(center: Offset(head.dx, head.dy + r * 0.6), width: r * 0.18, height: r * 0.22),
            _fill(const Color(0xFFFF6F7D)),
          );
        }
        if (a.kind == AnimalKind.cat || a.kind == AnimalKind.tiger || a.kind == AnimalKind.mouse) {
          final w = _stroke(const Color(0xFF5D4037).withValues(alpha: 0.6), r * 0.025);
          for (final side in const [-1.0, 1.0]) {
            for (var i = -1; i <= 1; i++) {
              c.drawLine(
                head + Offset(side * r * 0.3, r * 0.38 + i * r * 0.06),
                head + Offset(side * r * 0.85, r * 0.32 + i * r * 0.12),
                w,
              );
            }
          }
        }
    }
    // לחיים.
    for (final side in const [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(head.dx + side * r * 0.62, head.dy + r * 0.25),
          width: r * 0.28,
          height: r * 0.16,
        ),
        _fill(const Color(0xFFFF7A8A).withValues(alpha: 0.4)),
      );
    }
    if (a.kind == AnimalKind.boxer || a.kind == AnimalKind.pug) {
      // קמטים במצח.
      final w = _stroke(_darker(a.fur, 0.25), r * 0.04);
      for (var i = 0; i < 2; i++) {
        c.drawArc(
          Rect.fromCenter(center: head + Offset(0, -r * 0.45 + i * r * 0.12), width: r * 0.5, height: r * 0.2),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          w,
        );
      }
    }
  }

  void _extras() {
    if (a.kind == AnimalKind.unicorn) {
      final horn = Path()
        ..moveTo(head.dx - r * 0.13, head.dy - r * 0.85)
        ..lineTo(head.dx, head.dy - r * 1.55)
        ..lineTo(head.dx + r * 0.13, head.dy - r * 0.85)
        ..close();
      c.drawPath(
        horn,
        _shade(
          Rect.fromLTWH(head.dx - r * 0.2, head.dy - r * 1.6, r * 0.4, r * 0.8),
          const Color(0xFFFFD54F),
          light: 0.5,
        ),
      );
      final mane = [const Color(0xFFFF8FC0), const Color(0xFFB388FF), const Color(0xFF80DEEA)];
      for (var i = 0; i < 3; i++) {
        c.drawCircle(head + Offset(r * (0.55 + i * 0.15), -r * (0.75 - i * 0.3)), r * 0.24, _fill(mane[i]));
      }
    }
    if (a.kind == AnimalKind.pointer) {
      // כובע בלש קטן - זואי במהדורת אוואטאר.
      final hat = Rect.fromCenter(center: head + Offset(0, -r * 0.82), width: r * 1.4, height: r * 0.62);
      c.drawArc(hat, math.pi, math.pi, true, _shade(hat, const Color(0xFFC8A57A)));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: head + Offset(0, -r * 0.82), width: r * 1.7, height: r * 0.14),
          Radius.circular(r * 0.07),
        ),
        _fill(const Color(0xFF8D6E4A)),
      );
    }
  }

  // דמויות עם מבנה שונה.
  void _owl() {
    final body = Rect.fromCenter(center: Offset(s * 0.5, s * 0.6), width: s * 0.62, height: s * 0.7);
    c.drawOval(body, _shade(body, a.fur));
    final belly = Rect.fromCenter(center: Offset(s * 0.5, s * 0.75), width: s * 0.36, height: s * 0.36);
    c.drawOval(belly, _fill(a.accent));
    for (final side in const [-1.0, 1.0]) {
      final tuft = Path()
        ..moveTo(s * (0.5 + side * 0.12), s * 0.3)
        ..lineTo(s * (0.5 + side * 0.27), s * 0.18)
        ..lineTo(s * (0.5 + side * 0.28), s * 0.36)
        ..close();
      c.drawPath(tuft, _fill(_darker(a.fur, 0.1)));
      final ring = Offset(s * (0.5 + side * 0.13), s * 0.47);
      c.drawCircle(ring, s * 0.1, _fill(Colors.white));
      _eye(c, ring, s * 0.055);
    }
    final beak = Path()
      ..moveTo(s * 0.46, s * 0.55)
      ..lineTo(s * 0.54, s * 0.55)
      ..lineTo(s * 0.5, s * 0.63)
      ..close();
    c.drawPath(beak, _fill(const Color(0xFFFFA726)));
  }

  void _penguin() {
    final body = Rect.fromCenter(center: Offset(s * 0.5, s * 0.6), width: s * 0.6, height: s * 0.74);
    c.drawOval(body, _shade(body, a.fur));
    final face = Rect.fromCenter(center: Offset(s * 0.5, s * 0.58), width: s * 0.44, height: s * 0.56);
    c.drawOval(face, _fill(a.accent));
    for (final side in const [-1.0, 1.0]) {
      _eye(c, Offset(s * (0.5 + side * 0.1), s * 0.47), s * 0.04);
    }
    final beak = Path()
      ..moveTo(s * 0.45, s * 0.53)
      ..lineTo(s * 0.55, s * 0.53)
      ..lineTo(s * 0.5, s * 0.6)
      ..close();
    c.drawPath(beak, _fill(const Color(0xFFFFA726)));
    c.drawOval(
      Rect.fromCenter(center: Offset(s * 0.4, s * 0.58), width: s * 0.07, height: s * 0.04),
      _fill(const Color(0xFFFF8A9A).withValues(alpha: 0.6)),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(s * 0.6, s * 0.58), width: s * 0.07, height: s * 0.04),
      _fill(const Color(0xFFFF8A9A).withValues(alpha: 0.6)),
    );
  }

  void _chick() {
    final body = Rect.fromCenter(center: Offset(s * 0.5, s * 0.58), width: s * 0.66, height: s * 0.66);
    c.drawOval(body, _shade(body, a.fur, light: 0.45));
    for (var i = 0; i < 3; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s * (0.46 + i * 0.04), s * 0.24 + i * 0.01 * s),
          width: s * 0.06,
          height: s * 0.12,
        ),
        _fill(a.fur),
      );
    }
    for (final side in const [-1.0, 1.0]) {
      _eye(c, Offset(s * (0.5 + side * 0.11), s * 0.52), s * 0.045);
    }
    final beak = Path()
      ..moveTo(s * 0.45, s * 0.58)
      ..lineTo(s * 0.55, s * 0.58)
      ..lineTo(s * 0.5, s * 0.65)
      ..close();
    c.drawPath(beak, _fill(a.accent));
  }

  void _frog() {
    final face = Rect.fromCenter(center: Offset(s * 0.5, s * 0.6), width: s * 0.74, height: s * 0.56);
    c.drawOval(Rect.fromLTWH(s * 0.2, s * 0.8, s * 0.6, s * 0.4), _shade(face, a.fur));
    c.drawOval(face, _shade(face, a.fur));
    for (final side in const [-1.0, 1.0]) {
      final bump = Rect.fromCircle(center: Offset(s * (0.5 + side * 0.18), s * 0.36), radius: s * 0.12);
      c.drawOval(bump, _shade(bump, a.fur));
      c.drawCircle(bump.center, s * 0.08, _fill(Colors.white));
      _eye(c, bump.center, s * 0.045);
    }
    final smile = Path()
      ..moveTo(s * 0.32, s * 0.64)
      ..quadraticBezierTo(s * 0.5, s * 0.78, s * 0.68, s * 0.64);
    c.drawPath(smile, _stroke(_darker(a.fur, 0.45), s * 0.02));
    c.drawOval(
      Rect.fromCenter(center: Offset(s * 0.3, s * 0.62), width: s * 0.08, height: s * 0.05),
      _fill(const Color(0xFFFF8A9A).withValues(alpha: 0.6)),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(s * 0.7, s * 0.62), width: s * 0.08, height: s * 0.05),
      _fill(const Color(0xFFFF8A9A).withValues(alpha: 0.6)),
    );
  }

  void _robot() {
    final headRect = Rect.fromLTWH(s * 0.2, s * 0.28, s * 0.6, s * 0.5);
    c.drawLine(Offset(s * 0.5, s * 0.28), Offset(s * 0.5, s * 0.16), _stroke(const Color(0xFF90A4AE), s * 0.025));
    c.drawCircle(Offset(s * 0.5, s * 0.15), s * 0.035, _fill(a.accent));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.22, s * 0.8, s * 0.56, s * 0.4), Radius.circular(s * 0.1)),
      _shade(headRect, a.fur),
    );
    c.drawRRect(RRect.fromRectAndRadius(headRect, Radius.circular(s * 0.14)), _shade(headRect, a.fur));
    final screen = headRect.deflate(s * 0.07);
    c.drawRRect(RRect.fromRectAndRadius(screen, Radius.circular(s * 0.09)), _fill(const Color(0xFF1E2140)));
    for (final side in const [-1.0, 1.0]) {
      c.drawCircle(Offset(s * (0.5 + side * 0.1), s * 0.5), s * 0.045, _fill(a.accent));
    }
    final smile = Path()
      ..moveTo(s * 0.43, s * 0.6)
      ..quadraticBezierTo(s * 0.5, s * 0.65, s * 0.57, s * 0.6);
    c.drawPath(smile, _stroke(a.accent, s * 0.018));
  }

  void _alien() {
    final face = Rect.fromCenter(center: Offset(s * 0.5, s * 0.52), width: s * 0.62, height: s * 0.66);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.22, s * 0.8, s * 0.56, s * 0.4), Radius.circular(s * 0.18)),
      _shade(face, a.fur),
    );
    for (final side in const [-1.0, 1.0]) {
      c.drawLine(
        Offset(s * (0.5 + side * 0.12), s * 0.24),
        Offset(s * (0.5 + side * 0.2), s * 0.1),
        _stroke(a.fur, s * 0.025),
      );
      c.drawCircle(Offset(s * (0.5 + side * 0.2), s * 0.1), s * 0.04, _fill(a.accent));
    }
    c.drawOval(face, _shade(face, a.fur));
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.translate(s * (0.5 + side * 0.13), s * 0.5);
      c.rotate(side * 0.35);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.14, height: s * 0.2),
        _fill(const Color(0xFF1B1B2F)),
      );
      c.drawCircle(Offset(-s * 0.02, -s * 0.04), s * 0.025, _fill(Colors.white));
      c.restore();
    }
    final smile = Path()
      ..moveTo(s * 0.44, s * 0.68)
      ..quadraticBezierTo(s * 0.5, s * 0.73, s * 0.56, s * 0.68);
    c.drawPath(smile, _stroke(_darker(a.fur, 0.5), s * 0.018));
  }
}
