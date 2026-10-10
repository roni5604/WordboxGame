import 'package:flutter/widgets.dart';

void setBrowserTopColor(Color color) {}

/// האם לדפדפן יש תפריט שיתוף מובנה (Web Share API). בנייטיב - תמיד כן.
bool browserCanShare() => true;

/// האם המסך מתחלף עכשיו בעקבות ניווט של הדפדפן (החלקה/כפתור אחורה) שהדפדפן
/// כבר הנפיש בעצמו. בנייטיב - אף פעם.
bool isBrowserHistoryNavigation() => false;

/// הפעלה/כיבוי של חסימת "אחורה" של הדפדפן (באמצע משחק).
void setBrowserBackGuard(bool enabled) {}

/// מאזין לניסיון "אחורה" שנחסם. מחזיר פונקציה להסרת המאזין.
void Function() onBrowserBackBlocked(void Function() callback) => () {};
