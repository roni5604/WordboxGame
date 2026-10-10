import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// סוגי המעברים בין מסכים באפליקציה:
///
/// * [appPage] - מסכי תפריט/הגדרות "רגילים": מעבר ההחלקה הסטנדרטי של
///   הפלטפורמה (באייפון כולל החלקה מהקצה אחורה, באנדרואיד fade-forward).
/// * [gamePage] - מסכי משחק, תוצאות ופתיחת שלב: "zoom" רך שמרגיש כמו כניסה
///   לזירה. **אין** החלקה אחורה - כדי שתנועת אצבע תוך כדי משחק לא תוציא
///   אותך מהשלב בטעות.
/// * [popupPage] - מסכים שמרגישים כמו חלון שנפתח מעל (חנות, פרופיל,
///   חברים): עולים מלמטה עם קפיץ קל.
Page<void> appPage(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, name: state.uri.toString(), child: child);

Page<void> gamePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.uri.toString(),
    child: child,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic);
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.08, end: 1).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 0.94).animate(outgoing),
            child: child,
          ),
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
