import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../game_engine/rewards/rarity.dart';
import 'haptics_stub.dart' if (dart.library.js_interop) 'haptics_web.dart' as web;

/// רטט אחיד לכל האפליקציה - מכבד את הגדרת "רטט" של השחקן/ית ועובד גם
/// באתר (אנדרואיד: navigator.vibrate, אייפון: הטיק ההפטי של Safari).
///
/// עוצמה לפי משמעות: לחיצה רגילה = קליל, חיבור אות = "קליק", מילה = בינוני,
/// פתיחת פרס = תבנית שמתעצמת לפי הדרגה (אגדי מרגיש כמו "זיקוקים ביד").
class Haptics {
  Haptics._();

  /// מתעדכן מהגדרות הפרופיל (ראו app.dart).
  static bool enabled = true;

  static void selection() => _fire(HapticFeedback.selectionClick, const [6]);
  static void light() => _fire(HapticFeedback.lightImpact, const [10]);
  static void medium() => _fire(HapticFeedback.mediumImpact, const [18]);
  static void heavy() => _fire(HapticFeedback.heavyImpact, const [30]);

  /// "הצלחה" - שתי פעימות קצרות (כמו אישור באייפון).
  static void success() => _pattern(const [_P.medium, _P.gap(90), _P.light], const [16, 70, 12]);

  /// שגיאה - שלוש פעימות קצרות ומהירות.
  static void error() => _pattern(
        const [_P.light, _P.gap(60), _P.light, _P.gap(60), _P.light],
        const [10, 50, 10, 50, 10],
      );

  /// לחיצה על תיבה סגורה - מתחזקת עם כל לחיצה ([step] 0..4).
  static void charge(int step) {
    if (step <= 0) {
      light();
    } else if (step == 1) {
      medium();
    } else {
      heavy();
    }
  }

  /// התיבה עלתה דרגה - "בום" ואחריו רעד קצר.
  static void upgrade(Rarity to) {
    final extra = to.index >= Rarity.epic.index;
    _pattern(
      [_P.heavy, const _P.gap(70), _P.medium, if (extra) ...[const _P.gap(60), _P.heavy]],
      [32, 50, 18, if (extra) ...[45, 32]],
    );
  }

  /// פתיחת הפרס - חגיגה שגדלה לפי הדרגה: רגיל = פעימה אחת, אגדי = "זיקוקים".
  static void celebrate(Rarity rarity) {
    switch (rarity) {
      case Rarity.common:
        _pattern(const [_P.medium], const [20]);
      case Rarity.uncommon:
        _pattern(const [_P.heavy, _P.gap(110), _P.light], const [26, 90, 12]);
      case Rarity.rare:
        _pattern(
          const [_P.heavy, _P.gap(90), _P.medium, _P.gap(90), _P.light],
          const [30, 70, 18, 70, 12],
        );
      case Rarity.epic:
        _pattern(
          const [_P.heavy, _P.gap(80), _P.heavy, _P.gap(120), _P.medium, _P.gap(90), _P.medium, _P.gap(90), _P.light],
          const [40, 60, 40, 100, 20, 70, 20, 70, 12],
        );
      case Rarity.legendary:
        _pattern(
          const [
            _P.heavy, _P.gap(70), _P.heavy, _P.gap(70), _P.heavy, _P.gap(160), //
            _P.medium, _P.gap(110), _P.medium, _P.gap(110), _P.light, _P.gap(130), //
            _P.heavy, _P.gap(90), _P.light,
          ],
          const [50, 50, 50, 50, 60, 140, 24, 90, 24, 90, 14, 110, 45, 70, 14],
        );
    }
  }

  static void _fire(Future<void> Function() native, List<int> webPattern) {
    if (!enabled) return;
    if (kIsWeb) {
      web.webVibrate(webPattern);
    } else {
      native();
    }
  }

  static void _pattern(List<_P> native, List<int> webPattern) {
    if (!enabled) return;
    if (kIsWeb) {
      web.webVibrate(webPattern);
      return;
    }
    var delay = Duration.zero;
    for (final p in native) {
      if (p.gapMs > 0) {
        delay += Duration(milliseconds: p.gapMs);
        continue;
      }
      if (delay == Duration.zero) {
        p.fire();
      } else {
        Timer(delay, p.fire);
      }
    }
  }
}

/// פעימה בתבנית רטט (או הפסקה).
class _P {
  final int strength; // 0 קליל, 1 בינוני, 2 חזק
  final int gapMs;
  const _P._(this.strength) : gapMs = 0;
  const _P.gap(this.gapMs) : strength = -1;

  static const light = _P._(0);
  static const medium = _P._(1);
  static const heavy = _P._(2);

  void fire() {
    if (!Haptics.enabled) return;
    switch (strength) {
      case 0:
        HapticFeedback.lightImpact();
      case 1:
        HapticFeedback.mediumImpact();
      case 2:
        HapticFeedback.heavyImpact();
    }
  }
}
