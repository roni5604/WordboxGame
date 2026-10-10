import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart' as impl;

/// Flutter Web תמיד מדווח "אזור בטוח" של 0 - גם באייפון עם notch / Dynamic
/// Island ופס בית. index.html מוסיף `viewport-fit=cover` (כדי שהרקע ימשיך עד
/// הקצוות) ואלמנט מדידה עם `env(safe-area-inset-*)`; כאן קוראים את הערכים
/// ומזריקים אותם ל-MediaQuery, כך שכל SafeArea באפליקציה עובד גם באתר.
class WebSafeArea extends StatefulWidget {
  final Widget child;
  const WebSafeArea({super.key, required this.child});

  @override
  State<WebSafeArea> createState() => _WebSafeAreaState();
}

class _WebSafeAreaState extends State<WebSafeArea> with WidgetsBindingObserver {
  EdgeInsets _insets = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // הדפדפן מחשב את env() רק אחרי שה-viewport התעדכן - בודקים שוב קצת אחרי.
    Future.delayed(const Duration(milliseconds: 400), _refresh);
    Future.delayed(const Duration(milliseconds: 1500), _refresh);
  }

  @override
  void dispose() {
    if (kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _refresh();
    Future.delayed(const Duration(milliseconds: 300), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final next = impl.readSafeAreaInsets();
    if (next != _insets) setState(() => _insets = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _insets == EdgeInsets.zero) return widget.child;
    final mq = MediaQuery.of(context);
    EdgeInsets merge(EdgeInsets a) => EdgeInsets.fromLTRB(
          a.left > _insets.left ? a.left : _insets.left,
          a.top > _insets.top ? a.top : _insets.top,
          a.right > _insets.right ? a.right : _insets.right,
          a.bottom > _insets.bottom ? a.bottom : _insets.bottom,
        );
    // כשהמקלדת פתוחה ה-padding התחתון מתאפס (כמו במכשיר אמיתי).
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final padding = merge(mq.padding);
    return MediaQuery(
      data: mq.copyWith(
        padding: keyboardOpen ? padding.copyWith(bottom: 0) : padding,
        viewPadding: merge(mq.viewPadding),
      ),
      child: widget.child,
    );
  }
}
