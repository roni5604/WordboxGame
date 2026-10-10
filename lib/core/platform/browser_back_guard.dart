import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'browser_chrome_stub.dart' if (dart.library.js_interop) 'browser_chrome_web.dart' as impl;

/// באתר: כל עוד המסך הזה מוצג, "אחורה" של הדפדפן (החלקה מהקצה באייפון /
/// כפתור אחורה) לא יוצא ממנו - הניווט מבוטל ו-[onBlocked] נקרא (למשל
/// פתיחת תפריט השהיה). בנייטיב PopScope כבר מטפל בזה, וכאן אין השפעה.
class BrowserBackGuard extends StatefulWidget {
  final VoidCallback onBlocked;
  final Widget child;

  const BrowserBackGuard({super.key, required this.onBlocked, required this.child});

  @override
  State<BrowserBackGuard> createState() => _BrowserBackGuardState();
}

class _BrowserBackGuardState extends State<BrowserBackGuard> {
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    impl.setBrowserBackGuard(true);
    _unsubscribe = impl.onBrowserBackBlocked(() {
      if (mounted) widget.onBlocked();
    });
  }

  @override
  void dispose() {
    if (kIsWeb) {
      impl.setBrowserBackGuard(false);
      _unsubscribe?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// האם המעבר הנוכחי נגרם מניווט של הדפדפן שכבר הונפש על ידו.
bool get isBrowserHistoryNavigation => kIsWeb && impl.isBrowserHistoryNavigation();
