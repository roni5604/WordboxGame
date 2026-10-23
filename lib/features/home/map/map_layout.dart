import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../game_engine/models/level_config.dart';
import 'world_theme.dart';

/// שלב על המפה: [u] הוא המרחק לאורך השביל (גדל ככל שמתקדמים - "לעומק"
/// המסך), ו-[lateral] הוא ההיסט הצידי (‎-1 עד 1 = מקצה לקצה ברוחב המסך,
/// בקו המיקוד).
class MapNodeSpot {
  final LevelConfig level;
  final double u;
  final double lateral;

  const MapNodeSpot({required this.level, required this.u, required this.lateral});
}

/// "רמה" של עולם בנוף - מהנהר שלפניו עד הנהר שאחריו.
class MapWorldZone {
  final WorldTier tier;
  final int worldIndex;
  final double startU;
  final double endU;

  const MapWorldZone({required this.tier, required this.worldIndex, required this.startU, required this.endU});

  WorldTheme get theme => WorldTheme.of(worldIndex);
}

/// נהר זוהר שחוצה את המפה בין שני עולמות, עם גשר עץ במרכזו.
class MapRiver {
  final double u;
  final int toWorldIndex;

  const MapRiver({required this.u, required this.toWorldIndex});
}

/// קישוט בצד השביל (עץ, פרח, סלע...) - נבחר באופן דטרמיניסטי לכל עולם.
class MapProp {
  final double u;
  final double lateral;
  final PropKind kind;
  final double size;
  final int seed;
  final int worldIndex;

  const MapProp({
    required this.u,
    required this.lateral,
    required this.kind,
    required this.size,
    required this.seed,
    required this.worldIndex,
  });
}

/// הגיאומטריה של כל המפה (לא תלויה במסך ולא בהתקדמות השחקן/ית) - מחושבת
/// פעם אחת: מיקומי השלבים, העולמות, הנהרות והקישוטים.
class CampaignMapLayout {
  static const double levelGap = 250;

  /// המרחק בין השלב האחרון בעולם לראשון בעולם הבא (שם זורם הנהר).
  static const double worldGap = 640;
  static const double riverHalfWidth = 105;

  /// חצי רוחב השביל (ביחידות lateral).
  static const double roadHalfWidth = 0.30;
  static const double _amplitude = 0.40;

  final List<MapNodeSpot> nodes;
  final List<MapWorldZone> zones;
  final List<MapRiver> rivers;
  final List<MapProp> props;
  final List<double> _curveU;
  final List<double> _curveLat;

  CampaignMapLayout._(this.nodes, this.zones, this.rivers, this.props, this._curveU, this._curveLat);

  static final CampaignMapLayout campaign = CampaignMapLayout.build(CampaignLevels.all);

  factory CampaignMapLayout.build(List<LevelConfig> levels) {
    final nodes = <MapNodeSpot>[];
    final rivers = <MapRiver>[];
    final curveU = <double>[];
    final curveLat = <double>[];
    var u = 0.0;
    var inWorld = 0;
    for (int i = 0; i < levels.length; i++) {
      if (i > 0 && levels[i].tier != levels[i - 1].tier) {
        // הנהר באמצע הרווח; השביל חוצה אותו בדיוק במרכז (על הגשר).
        final riverU = u + worldGap / 2 - levelGap;
        rivers.add(MapRiver(u: riverU, toWorldIndex: levels[i].tier.index));
        curveU.add(riverU);
        curveLat.add(0);
        u += worldGap - levelGap;
        inWorld = 0;
      }
      // זיגזג רך שמתחיל ונגמר קרוב למרכז (ליד הגשרים).
      final phase = inWorld * 0.95 + levels[i].tier.index * 1.7;
      final edgeFade = math.min(1.0, 0.45 + 0.25 * math.min(inWorld, 2));
      final lateral = _amplitude * math.sin(phase) * edgeFade;
      nodes.add(MapNodeSpot(level: levels[i], u: u, lateral: lateral));
      curveU.add(u);
      curveLat.add(lateral);
      u += levelGap;
      inWorld++;
    }

    final zones = <MapWorldZone>[];
    var start = -100000.0;
    var tier = levels.first.tier;
    for (final river in rivers) {
      zones.add(MapWorldZone(tier: tier, worldIndex: tier.index, startU: start, endU: river.u));
      start = river.u;
      tier = CampaignLevels.worldOrder.firstWhere((t) => t.index == river.toWorldIndex, orElse: () => tier);
    }
    zones.add(MapWorldZone(tier: tier, worldIndex: tier.index, startU: start, endU: 100000));

    final layout = CampaignMapLayout._(nodes, zones, rivers, const [], curveU, curveLat);
    return CampaignMapLayout._(nodes, zones, rivers, layout._buildProps(), curveU, curveLat);
  }

  double get firstU => nodes.first.u;
  double get lastU => nodes.last.u;

  MapWorldZone zoneAt(double u) {
    for (final zone in zones) {
      if (u < zone.endU) return zone;
    }
    return zones.last;
  }

  MapNodeSpot nodeFor(int levelNumber) => nodes[(levelNumber - 1).clamp(0, nodes.length - 1)];

  /// ההיסט הצידי של מרכז השביל במרחק [u] - עקומה חלקה (Catmull-Rom)
  /// שעוברת דרך כל השלבים ודרך מרכז כל גשר.
  double roadLateral(double u) {
    final us = _curveU;
    if (u <= us.first) return _curveLat.first;
    if (u >= us.last) return _curveLat.last;
    var lo = 0;
    var hi = us.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (us[mid] <= u) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final u0 = us[lo];
    final u1 = us[hi];
    final p0 = _curveLat[lo];
    final p1 = _curveLat[hi];
    final span = u1 - u0;
    double tangent(int i) {
      final a = math.max(0, i - 1);
      final b = math.min(us.length - 1, i + 1);
      return (_curveLat[b] - _curveLat[a]) / (us[b] - us[a]) * span;
    }

    final m0 = tangent(lo);
    final m1 = tangent(hi);
    final t = (u - u0) / span;
    final t2 = t * t;
    final t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * m1;
  }

  bool _nearRiver(double u, double margin) => rivers.any((r) => (u - r.u).abs() < riverHalfWidth + margin);

  List<MapProp> _buildProps() {
    final props = <MapProp>[];
    final from = firstU - 1400;
    final to = lastU + 9000;
    var seed = 0;
    // קישוטים גדולים לצדי השביל - "מסגרת" הנוף, כמו בתים ועצים במפות קלאסיות.
    for (var u = from; u < to; u += 95) {
      for (final side in const [-1, 1]) {
        seed++;
        final rng = math.Random(seed * 7919 + 31);
        final pu = u + rng.nextDouble() * 70;
        if (_nearRiver(pu, 40)) continue;
        final zone = zoneAt(pu);
        final kinds = zone.theme.props;
        final lateral = side * (0.78 + rng.nextDouble() * 0.62);
        props.add(MapProp(
          u: pu,
          lateral: lateral,
          kind: kinds[rng.nextInt(kinds.length)],
          size: 0.75 + rng.nextDouble() * 0.55,
          seed: seed,
          worldIndex: zone.worldIndex,
        ));
      }
    }
    // פרטים קטנים על הקרקע (פרחים, נבטים, סלעים) - רק מחוץ לשביל.
    for (var u = from; u < to; u += 120) {
      seed++;
      final rng = math.Random(seed * 104729 + 7);
      final pu = u + rng.nextDouble() * 90;
      if (_nearRiver(pu, 30)) continue;
      final lateral = (rng.nextDouble() * 2 - 1) * 1.1;
      if ((lateral - roadLateral(pu)).abs() < roadHalfWidth + 0.14) continue;
      final zone = zoneAt(pu);
      final small = zone.theme.props.where((k) => _isSmall(k)).toList();
      if (small.isEmpty) continue;
      props.add(MapProp(
        u: pu,
        lateral: lateral,
        kind: small[rng.nextInt(small.length)],
        size: 0.45 + rng.nextDouble() * 0.25,
        seed: seed,
        worldIndex: zone.worldIndex,
      ));
    }
    props.sort((a, b) => a.u.compareTo(b.u));
    return props;
  }

  static bool _isSmall(PropKind kind) => switch (kind) {
        PropKind.sprout || PropKind.flower || PropKind.mushroom || PropKind.rock || PropKind.crystal => true,
        _ => false,
      };

  /// האינדקס הראשון ב-[props] עם u >= [u] (חיפוש בינארי).
  int firstPropAtOrAfter(double u) {
    var lo = 0;
    var hi = props.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (props[mid].u < u) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// הקרנה פרספקטיבית של המפה על המסך: הקרקע "שוכבת" ונמתחת אל קו אופק,
/// כך שהשלבים הבאים מתרחקים ומתכווצים לכיוון החלק העליון של המסך.
///
/// [camera] הוא ה-u שנמצא בדיוק על קו המיקוד ([focusY]).
class MapProjection {
  final Size size;
  final double horizonY;
  final double focusY;
  final double camera;

  /// עומק המצלמה מקו המיקוד - ככל שהוא גדול יותר, הפרספקטיבה "שטוחה" יותר.
  static const double depth = 1250;

  /// ריכוך ההקטנה של אובייקטים (שלבים, דמויות) - כדי שגם הרחוקים יישארו קריאים.
  static const double _billboardExponent = 0.72;

  const MapProjection({required this.size, required this.horizonY, required this.focusY, required this.camera});

  /// ההקרנה של מסך המפה: האופק מתחת לסרגל העליון, קו המיקוד (השלב
  /// הנוכחי) בערך בשליש התחתון - כך רואים הרבה "דרך" קדימה.
  factory MapProjection.screen(Size size, double topInset, double camera) => MapProjection(
        size: size,
        horizonY: topInset + 122,
        focusY: size.height * 0.70,
        camera: camera,
      );

  /// עד כמה רחוק קדימה (ביחידות u) עוד מציגים שלבים ודמויות.
  static const double visibleAhead = 1900;

  /// עד כמה מאחורי קו המיקוד עוד מציגים (מתחת לתחתית המסך כבר לא רואים).
  static const double visibleBehind = 520;

  double get _span => focusY - horizonY;

  double _z(double u) => math.max(u - camera + depth, 60);

  /// היחס הפרספקטיבי האמיתי (1 בקו המיקוד, קטן לכיוון האופק).
  double ratio(double u) => depth / _z(u);

  double y(double u) => horizonY + _span * ratio(u);

  double x(double u, double lateral) => size.width / 2 + lateral * (size.width / 2) * ratio(u);

  Offset point(double u, double lateral) => Offset(x(u, lateral), y(u));

  /// קנה המידה של אובייקט "עומד" (שלב, דמות, שלט) במרחק [u].
  double billboardScale(double u) => math.min(1.32, math.pow(ratio(u), _billboardExponent).toDouble());

  /// ה-u שמוצג בגובה [screenY] על המסך (ההפך של [y]).
  double uAt(double screenY) {
    final dy = math.max(screenY - horizonY, 1.0);
    return camera - depth + depth * _span / dy;
  }

  /// כמה יחידות u זזות כשגוררים אצבע מגובה [fromY] ל-[toY] על המסך -
  /// הנקודה שהייתה מתחת לאצבע נשארת מתחתיה, כך שהקרקע "נצמדת" לאצבע.
  double dragDelta(double fromY, double toY) {
    double inv(double screenY) => 1 / math.max(screenY - horizonY, 90.0);
    return depth * _span * (inv(fromY) - inv(toY));
  }

  /// מהירות הטלטול (fling) ביחידות u לשנייה, לפי קו המיקוד.
  double flingVelocity(double pixelsPerSecond) => pixelsPerSecond * depth / _span;
}
