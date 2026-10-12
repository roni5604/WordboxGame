import 'dart:ui';

import 'package:flutter/material.dart';

/// גלילה אחידה בכל האפליקציה - מה ש-Lenis עושה לאתרים, בגרסת משחק:
/// גלילה "חלקה" עם תנופה וקפיצה רכה בקצוות (כמו iOS) גם באנדרואיד ובאתר,
/// במקום עצירה חדה/זוהר כחול בקצה. גם עכבר יכול לגרור (בדיקות במחשב).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
