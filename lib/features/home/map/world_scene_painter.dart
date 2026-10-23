import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/level_node.dart';
import 'map_layout.dart';
import 'world_theme.dart';

/// מצייר את כל הנוף של מפת השלבים בפרספקטיבה: שמיים ואופק, "רמות" הקרקע
/// של העולמות, השביל המתפתל עם עקבות הכפות של זואי, נהרות זוהרים עם גשרים
/// במעברים בין עולמות, קישוטים לצדי הדרך וגחליליות.
///
/// מצויר מחדש בכל פריים של המצלמה ושל שעון האווירה ([ambient]) - בלי
/// לבנות מחדש ווידג'טים.
class WorldScenePainter extends CustomPainter {
  final CampaignMapLayout layout;
  final Animation<double> camera;
  final Animation<double> ambient;
  final double topInset;

  /// עד לאן השביל "נחקר" (השלב הבא לשחק) - עקבות הכפות בהירות עד כאן.
  final double trailU;

  static const double ambientSeconds = 40;

  /// עד כמה עמוק מציירים קרקע, נהרות ושביל - מעבר לזה רק ערפל האופק.
  static const double farDepth = 12000;

  WorldScenePainter({
    required this.layout,
    required this.camera,
    required this.ambient,
    required this.topInset,
    required this.trailU,
  }) : super(repaint: Listenable.merge([camera, ambient]));

  late MapProjection _p;
  late double _t;
  late Size _size;
  double _haze = 0;
  Color _hazeColor = Colors.white;

  Color _c(Color color) => _haze <= 0 ? color : Color.lerp(color, _hazeColor, _haze)!;

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    _p = MapProjection.screen(size, topInset, camera.value);
    _t = ambient.value * ambientSeconds;

    final focus = _p.camera + 180;
    final (fromTheme, toTheme, blend) = _skyBlend(focus);
    final sky = WorldTheme.lerpSky(fromTheme, toTheme, blend);
    final night = (fromTheme.night ? 1.0 : 0.0) * (1 - blend) + (toTheme.night ? 1.0 : 0.0) * blend;
    _hazeColor = sky.last;

    canvas.clipRect(Offset.zero & size);
    _paintSky(canvas, sky, night);
    _paintHorizon(canvas, layout.zoneAt(_p.camera + 9000).theme, sky.last);

    final uNear = _p.uAt(size.height + 12);
    final uFar = _p.camera + farDepth;
    _paintGround(canvas, uNear, uFar, night, sky.last);
    _paintRoad(canvas, uNear);
    _paintPawTrail(canvas, uNear);
    _paintNodeShadows(canvas, uNear);
    for (final river in layout.rivers) {
      _paintRiver(canvas, river, uNear);
    }
    _paintProps(canvas, uNear);
    _paintMist(canvas, sky.last, _p.y(uFar));
    _paintSparkles(canvas, layout.zoneAt(focus).theme, layout.zoneAt(focus).worldIndex);
    _paintVignette(canvas);
  }

  /// השמיים עוברים בהדרגה לצבעי העולם הבא כשמתקרבים לנהר.
  (WorldTheme, WorldTheme, double) _skyBlend(double focus) {
    for (final river in layout.rivers) {
      final d = focus - river.u;
      if (d.abs() < 520) {
        final before = layout.zoneAt(river.u - 1).theme;
        final after = layout.zoneAt(river.u + 1).theme;
        final t = ((d + 520) / 1040).clamp(0.0, 1.0);
        return (before, after, t * t * (3 - 2 * t));
      }
    }
    final theme = layout.zoneAt(focus).theme;
    return (theme, theme, 0);
  }

  // ---------------------------------------------------------------- שמיים

  void _paintSky(Canvas canvas, List<Color> sky, double night) {
    final rect = Rect.fromLTRB(0, 0, _size.width, _p.horizonY + 4);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // שמש (ביום) או ירח (בלילה) נמוך מעל האופק.
    final sunCenter = Offset(_size.width * 0.74, _p.horizonY - 22);
    final glowR = 110 - night * 50;
    canvas.drawCircle(
      sunCenter,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.55 - night * 0.3), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: glowR)),
    );
    canvas.drawCircle(sunCenter, 15 - night * 3, Paint()..color = Color.lerp(const Color(0xFFFFF6D8), const Color(0xFFFFF8E1), night)!);
    if (night > 0.05) {
      // חרמש ירח: עיגול בצבע השמיים שמכסה חלק מהעיגול הבהיר.
      final behind = Color.lerp(sky[1], sky[2], 0.72)!;
      canvas.drawCircle(sunCenter + const Offset(6, -4), 11, Paint()..color = behind.withValues(alpha: night));
    }

    if (night > 0.02) {
      final star = Paint();
      for (int i = 0; i < 36; i++) {
        final r = math.Random(i * 31 + 5);
        final pos = Offset(r.nextDouble() * _size.width, 10 + r.nextDouble() * (_p.horizonY - 40));
        final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(_t * (1.2 + r.nextDouble() * 2) + i));
        star.color = Colors.white.withValues(alpha: night * tw * 0.9);
        canvas.drawCircle(pos, 0.8 + r.nextDouble() * 1.2, star);
      }
    }

    final day = 1 - night;
    if (day > 0.02) {
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.5 * day);
      for (int i = 0; i < 4; i++) {
        final speed = 5.0 + i * 2.5;
        final span = _size.width + 180;
        final x = (i * 137.0 + _t * speed) % span - 90;
        final y = _p.horizonY * (0.32 + 0.14 * i);
        final s = 0.7 + (i % 3) * 0.2;
        canvas.drawCircle(Offset(x, y), 16 * s, cloud);
        canvas.drawCircle(Offset(x + 18 * s, y - 6 * s), 20 * s, cloud);
        canvas.drawCircle(Offset(x + 38 * s, y), 14 * s, cloud);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x - 8 * s, y, x + 50 * s, y + 12 * s), Radius.circular(6 * s)),
          cloud,
        );
      }
    }
  }

  /// קו הגבעות באופק - בצבעי העולם שרואים מרחוק (לעתים כבר העולם הבא!).
  void _paintHorizon(Canvas canvas, WorldTheme far, Color skyHorizon) {
    final h = _p.horizonY;
    final w = _size.width;
    final back = Color.lerp(far.groundFar, skyHorizon, 0.55)!;
    final front = Color.lerp(far.groundFar, skyHorizon, 0.28)!;

    Path hills(double height, double phase, double freq) {
      final path = Path()..moveTo(0, h + 2);
      for (double x = 0; x <= w + 8; x += 8) {
        final y = h - height * (0.6 + 0.4 * math.sin(x * freq + phase)) - height * 0.25 * math.sin(x * freq * 2.7 + phase * 2);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h + 2)
        ..close();
      return path;
    }

    switch (far.horizon) {
      case HorizonStyle.hills:
      case HorizonStyle.dunes:
      case HorizonStyle.blossomHills:
        final soft = far.horizon == HorizonStyle.dunes;
        canvas.drawPath(hills(soft ? 22 : 30, 1.3, soft ? 0.011 : 0.017), Paint()..color = back);
        canvas.drawPath(hills(soft ? 12 : 16, 4.1, soft ? 0.016 : 0.026), Paint()..color = front);
        if (far.horizon == HorizonStyle.blossomHills) {
          final blossom = Paint()..color = Color.lerp(const Color(0xFFFF9EC4), skyHorizon, 0.35)!;
          for (int i = 0; i < 9; i++) {
            final x = (i + 0.5) * w / 9 + math.sin(i * 2.3) * 12;
            canvas.drawCircle(Offset(x, h - 14 - (i % 3) * 3), 6 + (i % 2) * 2.0, blossom);
          }
        }
      case HorizonStyle.treeline:
        canvas.drawPath(hills(18, 2.0, 0.013), Paint()..color = back);
        final tree = Paint()..color = front;
        for (int i = 0; i < 26; i++) {
          final x = i * w / 25 + math.sin(i * 1.7) * 6;
          final th = 18 + (math.sin(i * 2.9) + 1) * 9;
          final tw = th * 0.42;
          canvas.drawPath(
            Path()
              ..moveTo(x, h - th)
              ..lineTo(x + tw, h + 1)
              ..lineTo(x - tw, h + 1)
              ..close(),
            tree,
          );
        }
      case HorizonStyle.peaks:
        final mountains = Path()..moveTo(0, h + 2);
        final tips = <Offset>[];
        for (int i = 0; i <= 7; i++) {
          final x = i * w / 7;
          final peak = i.isEven ? h - 42 - (i % 3) * 8 : h - 16;
          mountains.lineTo(x, peak);
          if (i.isEven) tips.add(Offset(x, peak));
        }
        mountains
          ..lineTo(w, h + 2)
          ..close();
        canvas.drawPath(mountains, Paint()..color = back);
        final snow = Paint()..color = Colors.white.withValues(alpha: 0.8);
        for (final tip in tips) {
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx + 9, tip.dy + 10)
              ..lineTo(tip.dx + 3, tip.dy + 8)
              ..lineTo(tip.dx - 2, tip.dy + 12)
              ..lineTo(tip.dx - 9, tip.dy + 10)
              ..close(),
            snow,
          );
        }
        canvas.drawPath(hills(10, 0.4, 0.03), Paint()..color = front);
    }
  }

  // ---------------------------------------------------------------- קרקע

  void _paintGround(Canvas canvas, double uNear, double uFar, double night, Color skyHorizon) {
    final groundRect = Rect.fromLTRB(0, _p.horizonY, _size.width, _size.height);
    // הרצועה הרחוקה ביותר (עד האופק) - צבע העולם שם, מעורפל.
    final farTheme = layout.zoneAt(uFar).theme;
    final farBand = Rect.fromLTRB(0, _p.horizonY, _size.width, _p.y(uFar) + 1);
    canvas.drawRect(
      farBand,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyHorizon, Color.lerp(farTheme.groundFar, skyHorizon, 0.3)!],
        ).createShader(farBand),
    );
    for (final zone in layout.zones) {
      final from = math.max(zone.startU, uNear);
      final to = math.min(zone.endU, uFar);
      if (to <= from) continue;
      final top = _p.y(to);
      final bottom = math.min(_p.y(from), _size.height);
      if (bottom <= top) continue;
      canvas.drawRect(
        Rect.fromLTRB(0, top, _size.width, bottom),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [zone.theme.groundFar, zone.theme.groundNear],
          ).createShader(groundRect),
      );
    }

    // פסי "כיסוח" עדינים לרוחב - נותנים תחושת תנועה ועומק כשגוללים.
    const band = 170.0;
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.05 - night * 0.015);
    final last = uFar;
    for (var k = (uNear / band).floor(); k * band < last; k++) {
      if (k.isOdd) continue;
      final top = _p.y(k * band + band / 2);
      final bottom = _p.y(k * band);
      if (bottom - top < 0.8) break;
      canvas.drawRect(Rect.fromLTRB(0, top, _size.width, bottom), stripe);
    }
  }

  void _paintRoad(Canvas canvas, double uNear) {
    final start = math.max(uNear, layout.firstU - 520);
    final end = math.min(_p.camera + farDepth, layout.lastU + 420);
    if (end <= start) return;
    const hw = CampaignMapLayout.roadHalfWidth;

    for (final zone in layout.zones) {
      final from = math.max(zone.startU, start);
      final to = math.min(zone.endU, end);
      if (to <= from) continue;
      final left = <Offset>[];
      final right = <Offset>[];
      // דגימה לפי פיקסלים על המסך - צפוף קרוב, דליל באופק.
      var y = _p.y(from);
      final yTop = _p.y(to);
      while (true) {
        final u = y <= yTop ? to : _p.uAt(y);
        final lat = layout.roadLateral(u);
        left.add(_p.point(u, lat - hw));
        right.add(_p.point(u, lat + hw));
        if (y <= yTop) break;
        y -= 5;
      }
      final path = Path()..addPolygon([...left, ...right.reversed], true);
      final theme = zone.theme;
      canvas.drawPath(path, Paint()..color = theme.road.withValues(alpha: 0.92));
      final edge = Paint()
        ..color = theme.roadEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(Path()..addPolygon(left, false), edge);
      canvas.drawPath(Path()..addPolygon(right, false), edge);
    }
  }

  /// עקבות כפות של זואי לאורך מרכז השביל: בהירות בחלק שכבר נחקר, חיוורות קדימה.
  void _paintPawTrail(Canvas canvas, double uNear) {
    const step = 64.0;
    final end = math.min(_p.camera + 4200, layout.lastU);
    final done = Paint();
    final ahead = Paint()..color = Colors.black.withValues(alpha: 0.07);
    final nodeUs = [
      for (final n in layout.nodes)
        if (n.u > uNear - 100 && n.u < end + 100) n.u,
    ];
    var k = ((math.max(uNear, layout.firstU)) / step).floor();
    for (; k * step < end; k++) {
      final u = k * step;
      if (u < layout.firstU) continue;
      if (layout.rivers.any((r) => (u - r.u).abs() < CampaignMapLayout.riverHalfWidth + 30)) continue;
      // לא מתחת לשלבים עצמם.
      if (nodeUs.any((n) => (u - n).abs() < 72)) continue;
      final side = k.isEven ? -0.045 : 0.045;
      final center = _p.point(u, layout.roadLateral(u) + side);
      final w = 15 * _p.ratio(u);
      if (w < 2.2) break;
      done.color = Color.lerp(layout.zoneAt(u).theme.roadEdge, const Color(0xFF5D3A1A), 0.45)!.withValues(alpha: 0.6);
      _paw(canvas, center, w, u <= trailU ? done : ahead);
    }
  }

  void _paw(Canvas canvas, Offset c, double w, Paint paint) {
    final h = w * 0.5;
    canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.62, height: h * 0.7), paint);
    for (int i = 0; i < 4; i++) {
      final a = -math.pi / 2 + (i - 1.5) * 0.55;
      final toe = c + Offset(math.cos(a) * w * 0.42, math.sin(a) * h * 0.62);
      canvas.drawOval(Rect.fromCenter(center: toe, width: w * 0.2, height: h * 0.26), paint);
    }
  }

  void _paintNodeShadows(Canvas canvas, double uNear) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
    for (final node in layout.nodes) {
      if (node.u < uNear - 100) continue;
      if (node.u > _p.camera + MapProjection.visibleAhead) break;
      final s = _p.billboardScale(node.u);
      final size = LevelNode.sizeFor(node.level) * s;
      final c = _p.point(node.u, node.lateral);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(0, size * 0.46), width: size * 0.95, height: size * 0.3), shadow);
    }
  }

  // ---------------------------------------------------------------- נהר וגשר

  void _paintRiver(Canvas canvas, MapRiver river, double uNear) {
    const hw = CampaignMapLayout.riverHalfWidth;
    if (river.u + hw < uNear || river.u - hw > _p.camera + farDepth) return;
    final theme = WorldTheme.of(river.toWorldIndex);
    final nextZone = layout.zoneAt(river.u + 1).theme;
    final yFar = _p.y(river.u + hw);
    final yNear = _p.y(river.u - hw);
    final rFar = _p.ratio(river.u + hw);
    final rNear = _p.ratio(river.u - hw);
    final w = _size.width;

    double wave(double x, double amp, double phase) => math.sin(x * 0.028 + _t * 1.4 + phase) * amp;

    Path band(double top, double bottom, double ampTop, double ampBottom) {
      final path = Path()..moveTo(-4, top);
      for (double x = -4; x <= w + 8; x += 10) {
        path.lineTo(x, top + wave(x, ampTop, 0));
      }
      for (double x = w + 8; x >= -4; x -= 10) {
        path.lineTo(x, bottom + wave(x, ampBottom, 2.1));
      }
      return path..close();
    }

    // הילה זוהרת סביב הנהר.
    final glowPad = 10 * rNear;
    canvas.drawPath(
      band(yFar - glowPad * 0.6, yNear + glowPad, 2 * rFar, 3 * rNear),
      Paint()..color = theme.waterGlow.withValues(alpha: 0.35),
    );

    final water = band(yFar, yNear, 2 * rFar, 3 * rNear);
    canvas.drawPath(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(theme.water, Colors.black, 0.25)!, theme.water, Color.lerp(theme.water, theme.waterGlow, 0.55)!],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(0, yFar, w, yNear)),
    );

    // ניצוצות זורמים על המים.
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, 2.6 * (rFar + rNear) / 2);
    for (int i = 0; i < 12; i++) {
      final r = math.Random(i * 53 + river.toWorldIndex);
      final lane = 0.2 + r.nextDouble() * 0.65;
      final y = yFar + (yNear - yFar) * lane;
      final len = (18 + r.nextDouble() * 26) * (rFar + (rNear - rFar) * lane);
      final x = (r.nextDouble() * (w + 80) + _t * (22 + r.nextDouble() * 18)) % (w + 80) - 40;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), streak);
    }

    // שפת ה"רמה" של העולם הבא (צוק קטן מעבר לנהר) + קצף בגדה הקרובה.
    final cliffH = 12 * rFar + 3;
    canvas.drawPath(
      band(yFar - cliffH, yFar + 1.5, 2 * rFar, 2 * rFar),
      Paint()..color = Color.lerp(nextZone.groundFar, Colors.black, 0.28)!,
    );
    canvas.drawPath(
      band(yFar - cliffH - 2, yFar - cliffH + 1.2, 2 * rFar, 2 * rFar),
      Paint()..color = Color.lerp(nextZone.groundFar, Colors.white, 0.35)!,
    );
    final foam = Path()..moveTo(-4, yNear);
    for (double x = -4; x <= w + 8; x += 10) {
      foam.lineTo(x, yNear + wave(x, 3 * rNear, 2.1));
    }
    canvas.drawPath(
      foam,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * rNear,
    );

    _paintBridge(canvas, river, yFar - cliffH * 0.4, yNear + 2 * rNear, rFar, rNear);
  }

  void _paintBridge(Canvas canvas, MapRiver river, double yFar, double yNear, double rFar, double rNear) {
    const hw = CampaignMapLayout.roadHalfWidth * 0.62;
    final cx = _size.width / 2;
    final halfFar = hw * (_size.width / 2) * rFar;
    final halfNear = hw * (_size.width / 2) * rNear;
    const wood = Color(0xFFC08552);
    const woodDark = Color(0xFF7A4B26);
    const woodLight = Color(0xFFE2AC74);

    final deck = Path()
      ..moveTo(cx - halfFar, yFar)
      ..lineTo(cx + halfFar, yFar)
      ..lineTo(cx + halfNear, yNear)
      ..lineTo(cx - halfNear, yNear)
      ..close();
    canvas.drawPath(deck.shift(Offset(0, 4 * rNear)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawPath(deck, Paint()..color = wood);

    final plank = Paint()
      ..color = woodDark.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, 1.6 * rNear);
    const planks = 9;
    for (int i = 1; i < planks; i++) {
      final t = i / planks;
      final y = yNear + (yFar - yNear) * t;
      final half = halfNear + (halfFar - halfNear) * t;
      canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), plank);
    }

    // מעקות ועמודים.
    final rail = Paint()
      ..color = woodLight
      ..strokeWidth = math.max(1.5, 3 * rNear)
      ..strokeCap = StrokeCap.round;
    final post = Paint()
      ..color = woodDark
      ..strokeWidth = math.max(1.5, 3.4 * rNear)
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      final nearBase = Offset(cx + side * halfNear, yNear);
      final farBase = Offset(cx + side * halfFar, yFar);
      final nearTop = nearBase - Offset(0, 16 * rNear);
      final farTop = farBase - Offset(0, 16 * rFar);
      for (final t in const [0.0, 0.5, 1.0]) {
        final base = Offset.lerp(nearBase, farBase, t)!;
        final top = Offset.lerp(nearTop, farTop, t)!;
        canvas.drawLine(base, top, post);
      }
      canvas.drawLine(nearTop, farTop, rail);
    }
  }

  // ---------------------------------------------------------------- קישוטים

  void _paintProps(Canvas canvas, double uNear) {
    final props = layout.props;
    final farLimit = _p.camera + 5600;
    var i = layout.firstPropAtOrAfter(farLimit) - 1;
    final stop = uNear - 260;
    for (; i >= 0; i--) {
      final prop = props[i];
      if (prop.u < stop) break;
      final ratio = _p.ratio(prop.u);
      final s = _p.billboardScale(prop.u) * prop.size;
      if (s * 100 < 4) continue;
      final base = _p.point(prop.u, prop.lateral);
      if (base.dx < -110 * s || base.dx > _size.width + 110 * s) continue;
      _haze = ((0.6 - ratio) / 0.42).clamp(0.0, 0.85);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(s * (prop.lateral < 0 ? 1 : -1), s);
      _drawProp(canvas, prop);
      canvas.restore();
    }
    _haze = 0;
  }

  static const _petals = [Color(0xFFFF6F91), Color(0xFFFFFFFF), Color(0xFFB388FF), Color(0xFFFFD54F), Color(0xFF64B5F6)];

  Color _foliage(int world, {bool dark = false}) {
    const light = [Color(0xFF5CC253), Color(0xFF2FB3A0), Color(0xFF7CC66B), Color(0xFF23915F), Color(0xFF6C93B8)];
    const shade = [Color(0xFF3E9A3B), Color(0xFF1F8A7E), Color(0xFF55A64C), Color(0xFF0F5E42), Color(0xFF4A6E91)];
    return _c((dark ? shade : light)[world % light.length]);
  }

  void _drawProp(Canvas canvas, MapProp prop) {
    final rng = math.Random(prop.seed);
    final fill = Paint();
    switch (prop.kind) {
      case PropKind.sprout:
        canvas.drawLine(
          Offset.zero,
          const Offset(0, -26),
          Paint()
            ..color = _foliage(prop.worldIndex, dark: true)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
        _leaf(canvas, const Offset(-9, -28), 20, 10, -0.5, _foliage(prop.worldIndex));
        _leaf(canvas, const Offset(9, -31), 22, 11, 0.45, _foliage(prop.worldIndex));
      case PropKind.flower:
        canvas.drawLine(
          Offset.zero,
          const Offset(0, -30),
          Paint()
            ..color = _foliage(prop.worldIndex, dark: true)
            ..strokeWidth = 3.5,
        );
        _leaf(canvas, const Offset(6, -12), 14, 7, 0.6, _foliage(prop.worldIndex));
        fill.color = _c(_petals[rng.nextInt(_petals.length)]);
        for (int i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5 + _t * 0.2;
          canvas.drawCircle(Offset(math.cos(a) * 8, -38 + math.sin(a) * 8), 7, fill);
        }
        canvas.drawCircle(const Offset(0, -38), 5, Paint()..color = _c(const Color(0xFFFFB300)));
      case PropKind.bush:
        fill.color = _foliage(prop.worldIndex, dark: true);
        canvas.drawCircle(const Offset(-17, -15), 18, fill);
        canvas.drawCircle(const Offset(16, -14), 17, fill);
        fill.color = _foliage(prop.worldIndex);
        canvas.drawCircle(const Offset(0, -27), 21, fill);
        canvas.drawCircle(const Offset(-12, -19), 14, fill);
        canvas.drawCircle(const Offset(6, -36), 7, Paint()..color = _c(Colors.white.withValues(alpha: 0.25)));
        if (rng.nextBool()) {
          fill.color = _c(_petals[rng.nextInt(_petals.length)]);
          canvas.drawCircle(const Offset(-8, -30), 3.5, fill);
          canvas.drawCircle(const Offset(10, -22), 3.5, fill);
        }
      case PropKind.mushroom:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -24, 14, 24), const Radius.circular(6)),
          Paint()..color = _c(const Color(0xFFFFF1DC)),
        );
        final cap = Path()
          ..moveTo(-24, -20)
          ..quadraticBezierTo(-24, -48, 0, -48)
          ..quadraticBezierTo(24, -48, 24, -20)
          ..close();
        canvas.drawPath(cap, Paint()..color = _c(rng.nextBool() ? const Color(0xFFFF5A5F) : const Color(0xFFB36BFF)));
        fill.color = _c(Colors.white.withValues(alpha: 0.9));
        canvas.drawCircle(const Offset(-10, -34), 4, fill);
        canvas.drawCircle(const Offset(8, -38), 5, fill);
        canvas.drawCircle(const Offset(14, -26), 3, fill);
      case PropKind.roundTree:
      case PropKind.blossomTree:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -46, 12, 46), const Radius.circular(4)),
          Paint()..color = _c(const Color(0xFF8A5A33)),
        );
        final blossom = prop.kind == PropKind.blossomTree;
        fill.color = blossom ? _c(const Color(0xFFE76F9F)) : _foliage(prop.worldIndex, dark: true);
        canvas.drawCircle(const Offset(-22, -58), 22, fill);
        canvas.drawCircle(const Offset(22, -58), 22, fill);
        fill.color = blossom ? _c(const Color(0xFFFF9EC4)) : _foliage(prop.worldIndex);
        canvas.drawCircle(const Offset(0, -78), 32, fill);
        canvas.drawCircle(const Offset(-14, -64), 20, fill);
        canvas.drawCircle(const Offset(10, -92), 10, Paint()..color = _c(Colors.white.withValues(alpha: 0.22)));
        if (blossom) {
          fill.color = _c(Colors.white);
          for (int i = 0; i < 6; i++) {
            canvas.drawCircle(Offset(-24 + rng.nextDouble() * 48, -96 + rng.nextDouble() * 44), 3, fill);
          }
        }
      case PropKind.reeds:
        final stalk = Paint()
          ..color = _c(const Color(0xFF3E8E6E))
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final head = Paint()..color = _c(const Color(0xFF8D5A3B));
        for (int i = 0; i < 4; i++) {
          final x = -12.0 + i * 8;
          final top = -58.0 - (i.isEven ? 16 : 0);
          final sway = math.sin(_t * 1.3 + i + prop.seed) * 4;
          canvas.drawPath(
            Path()
              ..moveTo(x, 0)
              ..quadraticBezierTo(x, top / 2, x + sway, top),
            stalk,
          );
          if (i != 2) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x + sway, top + 6), width: 7, height: 16), const Radius.circular(4)),
              head,
            );
          }
        }
      case PropKind.rock:
        final rock = Path()
          ..moveTo(-28, 0)
          ..quadraticBezierTo(-30, -20, -10, -30)
          ..quadraticBezierTo(8, -38, 22, -24)
          ..quadraticBezierTo(32, -10, 28, 0)
          ..close();
        canvas.drawPath(rock, Paint()..color = _c(Color.lerp(const Color(0xFF8C8BA6), WorldTheme.of(prop.worldIndex).groundNear, 0.25)!));
        canvas.drawPath(
          Path()
            ..moveTo(-14, -26)
            ..quadraticBezierTo(4, -36, 18, -24)
            ..quadraticBezierTo(2, -24, -14, -26),
          Paint()..color = _c(Colors.white.withValues(alpha: 0.35)),
        );
      case PropKind.lilyPond:
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -6), width: 92, height: 26), Paint()..color = _c(const Color(0xFF1F7FA3)));
        canvas.drawOval(Rect.fromCenter(center: const Offset(-4, -8), width: 76, height: 18), Paint()..color = _c(const Color(0xFF4FC3E8)));
        fill.color = _c(const Color(0xFF3FAF5A));
        canvas.drawOval(Rect.fromCenter(center: const Offset(-18, -8), width: 22, height: 8), fill);
        canvas.drawOval(Rect.fromCenter(center: const Offset(16, -6), width: 18, height: 7), fill);
        canvas.drawCircle(const Offset(16, -10), 4, Paint()..color = _c(const Color(0xFFFF8AD8)));
      case PropKind.sunflower:
        canvas.drawLine(
          Offset.zero,
          const Offset(0, -70),
          Paint()
            ..color = _c(const Color(0xFF4E9A3E))
            ..strokeWidth = 5,
        );
        _leaf(canvas, const Offset(-10, -30), 22, 10, -0.5, _c(const Color(0xFF5DB54A)));
        _leaf(canvas, const Offset(10, -42), 22, 10, 0.5, _c(const Color(0xFF5DB54A)));
        final headC = const Offset(0, -80);
        final turn = math.sin(_t * 0.5 + prop.seed) * 0.12;
        fill.color = _c(const Color(0xFFFFC93C));
        for (int i = 0; i < 12; i++) {
          final a = i * math.pi / 6 + turn;
          canvas.save();
          canvas.translate(headC.dx + math.cos(a) * 14, headC.dy + math.sin(a) * 14);
          canvas.rotate(a);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 7), fill);
          canvas.restore();
        }
        canvas.drawCircle(headC, 10, Paint()..color = _c(const Color(0xFF7A4A1E)));
      case PropKind.pine:
      case PropKind.snowPine:
        canvas.drawRect(const Rect.fromLTWH(-5, -16, 10, 16), Paint()..color = _c(const Color(0xFF6B4226)));
        final snowy = prop.kind == PropKind.snowPine;
        for (int i = 0; i < 3; i++) {
          final base = -14.0 - i * 26;
          final half = 34.0 - i * 8;
          final tier = Path()
            ..moveTo(0, base - 42)
            ..lineTo(half, base)
            ..quadraticBezierTo(0, base + 6, -half, base)
            ..close();
          canvas.drawPath(tier, Paint()..color = _foliage(prop.worldIndex, dark: true));
          canvas.drawPath(
            Path()
              ..moveTo(0, base - 42)
              ..lineTo(half, base)
              ..quadraticBezierTo(half * 0.5, base + 3, 0, base + 2)
              ..close(),
            Paint()..color = _foliage(prop.worldIndex),
          );
          if (snowy) {
            canvas.drawPath(
              Path()
                ..moveTo(0, base - 42)
                ..lineTo(half * 0.38, base - 26)
                ..lineTo(0, base - 30)
                ..lineTo(-half * 0.38, base - 26)
                ..close(),
              Paint()..color = _c(Colors.white),
            );
          }
        }
      case PropKind.lantern:
        final flicker = 0.82 + 0.18 * math.sin(_t * 6 + prop.seed);
        const lamp = Offset(10, -74);
        canvas.drawCircle(
          lamp,
          44,
          Paint()
            ..shader = RadialGradient(
              colors: [const Color(0xFFFFD166).withValues(alpha: 0.55 * flicker), const Color(0x00FFD166)],
            ).createShader(Rect.fromCircle(center: lamp, radius: 44)),
        );
        final pole = Paint()
          ..color = _c(const Color(0xFF3B2A4A))
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(0, -86)
            ..quadraticBezierTo(0, -92, 10, -90),
          pole,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: lamp, width: 14, height: 18), const Radius.circular(4)),
          Paint()..color = Color.lerp(const Color(0xFFFFE08A), Colors.white, 0.3 * flicker)!,
        );
      case PropKind.crystal:
        void prism(Offset base, double w, double h, double tilt, Color color) {
          canvas.save();
          canvas.translate(base.dx, base.dy);
          canvas.rotate(tilt);
          final body = Path()
            ..moveTo(-w / 2, 0)
            ..lineTo(-w / 2, -h * 0.75)
            ..lineTo(0, -h)
            ..lineTo(w / 2, -h * 0.75)
            ..lineTo(w / 2, 0)
            ..close();
          canvas.drawPath(body, Paint()..color = _c(color));
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(0, -h)
              ..lineTo(w / 2, -h * 0.75)
              ..lineTo(w / 2, 0)
              ..close(),
            Paint()..color = _c(Colors.white.withValues(alpha: 0.28)),
          );
          canvas.restore();
        }
        final glow = 0.5 + 0.5 * math.sin(_t * 1.8 + prop.seed);
        canvas.drawCircle(
          const Offset(0, -24),
          34,
          Paint()
            ..shader = RadialGradient(
              colors: [const Color(0xFF7FE7FF).withValues(alpha: 0.35 * glow), const Color(0x007FE7FF)],
            ).createShader(Rect.fromCircle(center: const Offset(0, -24), radius: 34)),
        );
        prism(const Offset(-12, 0), 12, 34, -0.35, const Color(0xFFB388FF));
        prism(const Offset(12, 0), 11, 30, 0.3, const Color(0xFF64B5F6));
        prism(Offset.zero, 16, 50, 0, const Color(0xFF7FE7FF));
    }
  }

  void _leaf(Canvas canvas, Offset center, double w, double h, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(-w / 2, 0)
        ..quadraticBezierTo(0, -h, w / 2, 0)
        ..quadraticBezierTo(0, h, -w / 2, 0),
      Paint()..color = color,
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------- אווירה

  void _paintMist(Canvas canvas, Color skyHorizon, double farY) {
    final rect = Rect.fromLTRB(0, _p.horizonY - 6, _size.width, farY + 46);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyHorizon.withValues(alpha: 0.9), skyHorizon.withValues(alpha: 0.55), skyHorizon.withValues(alpha: 0)],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  /// חלקיקים מרחפים לפי העולם: אבקה, בועות, עלי כותרת, גחליליות, שלג.
  void _paintSparkles(Canvas canvas, WorldTheme theme, int world) {
    const drift = [-5.0, -26.0, 20.0, 0.0, 28.0];
    final vy = drift[world % drift.length];
    final top = _p.horizonY + 20;
    final span = _size.height - top;
    final halo = Paint();
    final dot = Paint();
    final count = theme.night ? 24 : 14;
    for (int i = 0; i < count; i++) {
      final r = math.Random(i * 911 + world);
      final baseX = r.nextDouble() * _size.width;
      final baseY = r.nextDouble() * span;
      final phase = r.nextDouble() * math.pi * 2;
      final x = baseX + math.sin(_t * (0.4 + r.nextDouble() * 0.5) + phase) * 22;
      final y = top + (baseY + _t * vy * (0.7 + r.nextDouble() * 0.6)) % span;
      final depth = (y - top) / span;
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(_t * (1.5 + r.nextDouble() * 2) + phase));
      final radius = (1.0 + depth * 1.6);
      if (world == 2) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(_t * 0.8 + phase);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 3, height: radius * 1.6), Paint()..color = const Color(0xFFFFB8D2).withValues(alpha: 0.85));
        canvas.restore();
        continue;
      }
      halo.color = theme.sparkle.withValues(alpha: (theme.night ? 0.18 : 0.1) * tw);
      dot.color = theme.sparkle.withValues(alpha: 0.95 * tw);
      canvas.drawCircle(Offset(x, y), radius * (theme.night ? 3.4 : 2.4), halo);
      canvas.drawCircle(Offset(x, y), radius, dot);
    }
  }

  void _paintVignette(Canvas canvas) {
    final rect = Offset.zero & _size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.05,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant WorldScenePainter old) =>
      old.layout != layout || old.topInset != topInset || old.trailU != trailU;
}
