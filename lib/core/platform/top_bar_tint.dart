import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'browser_chrome_stub.dart' if (dart.library.js_interop) 'browser_chrome_web.dart' as impl;

/// קובע את צבע הפס העליון של הדפדפן (שעה/סוללה באייפון) לפי המסך הנוכחי.
///
/// ממוקם בתוך כל מסך עם הצבע שבראש הרקע שלו. מתעדכן כשהמסך הופך לפעיל -
/// גם כשחוזרים אליו אחורה - כי ModalRoute.of יוצר תלות במצב "isCurrent".
class TopBarTint extends StatelessWidget {
  final Color color;
  final Widget child;

  const TopBarTint({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final route = ModalRoute.of(context);
      if (route == null || route.isCurrent) {
        WidgetsBinding.instance.addPostFrameCallback((_) => impl.setBrowserTopColor(color));
      }
    }
    return child;
  }
}
