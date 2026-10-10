import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../platform/browser_back_guard.dart';

/// כשהדפדפן כבר הנפיש את המעבר בעצמו (החלקה מהקצה באייפון / כפתור אחורה),
/// מחליפים מסך מיד - בלי אנימציה שנייה של Flutter אחרי זו של הדפדפן, שזה
/// בדיוק מה שנראה כמו "קפיצה". המסך שיוצא נעלם מיד, וזה שמתחת מוצג כמו שהוא.
/// לכל אנימציית מעבר: האם הוחלט שהיא "מעבר של הדפדפן". ההחלטה נקבעת פעם
/// אחת בתחילת המעבר ונשמרת עד סופו - כך המעבר לא משנה החלטה באמצע.
final Expando<bool> _browserNavLatch = Expando('browserNav');

Widget? _browserNavShortcut(Animation<double> animation, Animation<double> secondary, Widget child) {
  if (!kIsWeb) return null;
  bool animating(Animation<double> a) => a.status == AnimationStatus.forward || a.status == AnimationStatus.reverse;
  bool latch(Animation<double> a) {
    if (!animating(a)) {
      _browserNavLatch[a] = null;
      return false;
    }
    return _browserNavLatch[a] ??= isBrowserHistoryNavigation;
  }

  // המסך שנכנס/יוצא: נכנס מיד, או נעלם מיד.
  if (latch(animation)) {
    return animation.status == AnimationStatus.reverse ? const SizedBox.shrink() : child;
  }
  // המסך שמתחת: מוצג כמו שהוא, בלי "לחזור" מהצד אחרי האנימציה של הדפדפן.
  if (latch(secondary)) return child;
  return null;
}

/// סוגי המעברים בין מסכים באפליקציה:
///
/// * [appPage] - מסכי תפריט/הגדרות "רגילים": מעבר ההחלקה הסטנדרטי של
///   הפלטפורמה (באייפון כולל החלקה מהקצה אחורה, באנדרואיד fade-forward).
/// * [gamePage] - מסכי משחק, תוצאות ופתיחת שלב: "zoom" רך שמרגיש כמו כניסה
///   לזירה. **אין** החלקה אחורה - כדי שתנועת אצבע תוך כדי משחק לא תוציא
///   אותך מהשלב בטעות.
/// * [popupPage] - מסכים שמרגישים כמו חלון שנפתח מעל (חנות, פרופיל,
///   חברים): עולים מלמטה עם קפיץ קל.
Page<void> appPage(GoRouterState state, Widget child) {
  // בנייטיב: המעבר הטבעי של הפלטפורמה (באייפון כולל החלקה מהקצה).
  if (!kIsWeb) return MaterialPage<void>(key: state.pageKey, name: state.uri.toString(), child: child);
  // באתר: ההחלקה אחורה שייכת לדפדפן, אז בלי מחוות החלקה של Flutter שמתחרה
  // בה - מעבר "ציר משותף" נקי: המסך החדש נכנס בהחלקה קצרה + דהייה, והקודם
  // זז מעט לצד ונחלש.
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.uri.toString(),
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final shortcut = _browserNavShortcut(animation, secondaryAnimation, child);
      if (shortcut != null) return shortcut;
      // ב-RTL "קדימה" זה שמאלה: המסך החדש נכנס משמאל.
      final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
      final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final outCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: Offset(0.22 * dir, 0), end: Offset.zero).animate(inCurve),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.7)),
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset.zero, end: Offset(-0.12 * dir, 0)).animate(outCurve),
            child: FadeTransition(opacity: Tween<double>(begin: 1, end: 0.6).animate(outCurve), child: child),
          ),
        ),
      );
    },
  );
}

Page<void> gamePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.uri.toString(),
    child: child,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final shortcut = _browserNavShortcut(animation, secondaryAnimation, child);
      if (shortcut != null) return shortcut;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic);
      return FadeTransition(
        opacity: Tween<double>(
          begin: 0,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: const Interval(0, 0.6))),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.08, end: 1).animate(curved),
          child: ScaleTransition(scale: Tween<double>(begin: 1, end: 0.94).animate(outgoing), child: child),
        ),
      );
    },
  );
}

Page<void> popupPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.uri.toString(),
    child: child,
    transitionDuration: const Duration(milliseconds: 480),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final shortcut = _browserNavShortcut(animation, secondaryAnimation, child);
      if (shortcut != null) return shortcut;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// מעברי ברירת המחדל לכל הפלטפורמות (ראו AppTheme).
const kPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
  },
);
