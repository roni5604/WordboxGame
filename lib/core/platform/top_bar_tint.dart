import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'browser_chrome_stub.dart' if (dart.library.js_interop) 'browser_chrome_web.dart' as impl;

/// מקור האמת לצבע הפס העליון של הדפדפן (שעה/סוללה באייפון):
/// הצבע של המסך הפעיל, ומעליו - אם פתוח דיאלוג/חלון קופץ - צבע ההחשכה שלו,
/// בדיוק כמו שהמסך עצמו נראה מתחת לחלון.
class TopTint {
  TopTint._();

  static Color? _base;
  static final List<Color> _overlays = [];

  static void setScreenColor(Color color) {
    _base = color;
    _apply();
  }

  /// הצבע שמוצג כרגע בפס (צבע המסך + החשכת חלונות פתוחים).
  @visibleForTesting
  static Color? get effectiveColor {
    final base = _base;
    if (base == null) return null;
    var color = base;
    for (final overlay in _overlays) {
      color = Color.alphaBlend(overlay, color);
    }
    return color;
  }

  static void _apply() {
    final color = effectiveColor;
    if (color != null) impl.setBrowserTopColor(color);
  }
}

/// קובע את צבע הפס העליון של הדפדפן לפי המסך הנוכחי.
///
/// ממוקם בתוך כל מסך עם הצבע שבראש הרקע שלו. מתעדכן כשהמסך הופך לפעיל -
/// גם כשחוזרים אליו אחורה - כי ModalRoute.of יוצר תלות במצב "isCurrent".
/// העדכון נשלח כבר בפריים הראשון של מעבר המסך, כך שהפס משתנה יחד עם
/// הלחיצה ולא אחרי שהאנימציה נגמרת.
class TopBarTint extends StatelessWidget {
  final Color color;
  final Widget child;

  const TopBarTint({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final route = ModalRoute.of(context);
      if (route == null || route.isCurrent) {
        WidgetsBinding.instance.addPostFrameCallback((_) => TopTint.setScreenColor(color));
      }
    }
    return child;
  }
}

/// מחשיך את הפס העליון כשנפתח דיאלוג / חלון תחתון עם רקע מוחשך (כמו
/// באפליקציה אמיתית), ומחזיר אותו כשהחלון נסגר.
class TopTintObserver extends NavigatorObserver {
  final Map<Route<dynamic>, Color> _dimmers = {};

  Color? _barrierOf(Route<dynamic> route) {
    if (route is! PopupRoute) return null;
    final c = route.barrierColor;
    if (c == null || c.a == 0) return null;
    return c;
  }

  void _sync() {
    TopTint._overlays
      ..clear()
      ..addAll(_dimmers.values);
    TopTint._apply();
  }

  void _add(Route<dynamic>? route) {
    if (route == null) return;
    final c = _barrierOf(route);
    if (c == null) return;
    _dimmers[route] = c;
    _sync();
  }

  void _remove(Route<dynamic>? route) {
    if (route == null) return;
    if (_dimmers.remove(route) != null) _sync();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remove(oldRoute);
    _add(newRoute);
  }
}
