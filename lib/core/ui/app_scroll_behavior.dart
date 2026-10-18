import 'dart:ui';

import 'package:flutter/material.dart';

/// גלילה אחידה בכל האפליקציה: נעצרת בקצוות - בלי "גומי" שמושך את המסך
/// למטה/למעלה מעבר לתוכן ובלי זוהר כחול. מסך שהתוכן שלו נכנס כולו לא זז
/// בכלל. גם עכבר יכול לגרור (בדיקות במחשב).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());

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
