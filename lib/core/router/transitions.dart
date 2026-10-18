import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
/// * [appPage] - מסכי תפריט/הגדרות "רגילים": המסך החדש נכנס בהחלקה קצרה
///   + דהייה, והקודם זז מעט לצד ונחלש.
/// * [gamePage] - מסכי משחק, תוצאות ופתיחת שלב: "zoom" רך שמרגיש כמו כניסה
///   לזירה.
/// * [popupPage] - מסכים שמרגישים כמו חלון שנפתח מעל (חנות, פרופיל,
///   חברים): עולים מלמטה עם קפיץ קל.
///
/// החלקה ימינה מהקצה השמאלי חוזרת למסך הקודם (כמו באייפון, גם באתר) -
/// ב-[appPage] וב-[popupPage] תמיד, וב-[gamePage] רק עם `swipeBack: true`
/// (מפה, פתיחת שלב, אתגר יומי). במהלך משחק אין החלקה, כדי שתנועת אצבע על
/// הלוח לא תוציא מהשלב. מסך עם PopScope(canPop: false) לא נסגר בהחלקה.
Page<void> appPage(GoRouterState state, Widget child) {
  return _page(
    state,
    child,
    swipeBack: true,
    forward: const Duration(milliseconds: 380),
    reverse: const Duration(milliseconds: 300),
    builder: (context, animation, secondaryAnimation, child) {
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

Page<void> gamePage(GoRouterState state, Widget child, {bool swipeBack = false}) {
  return _page(
    state,
    child,
    swipeBack: swipeBack,
    forward: const Duration(milliseconds: 520),
    reverse: const Duration(milliseconds: 320),
    builder: (context, animation, secondaryAnimation, child) {
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
  return _page(
    state,
    child,
    swipeBack: true,
    forward: const Duration(milliseconds: 480),
    reverse: const Duration(milliseconds: 300),
    builder: (context, animation, secondaryAnimation, child) {
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

Page<void> _page(
  GoRouterState state,
  Widget child, {
  required bool swipeBack,
  required Duration forward,
  required Duration reverse,
  required RouteTransitionsBuilder builder,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.uri.toString(),
    child: swipeBack ? _SwipeBackDetector(child: child) : child,
    transitionDuration: forward,
    reverseTransitionDuration: reverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final shortcut = _browserNavShortcut(animation, secondaryAnimation, child);
      if (shortcut != null) return shortcut;
      return _SwipeAwareTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        builder: builder,
        child: child,
      );
    },
  );
}

/// בזמן החלקה אחורה (או בסיומה) המסך העליון זז ימינה עם האצבע והמסך
/// שמתחתיו נחשף מעט משמאל - במקום המעבר הרגיל של המסך, שבהיפוך נראה הפוך
/// לכיוון האצבע. מבנה העץ זהה בשני המצבים (רק האנימציות מתחלפות), כך
/// שמצב המסך נשמר.
class _SwipeAwareTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final RouteTransitionsBuilder builder;
  final Widget child;

  const _SwipeAwareTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.builder,
    required this.child,
  });

  static final _followIn = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final _followOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.3, 0));

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return builder(context, animation, secondaryAnimation, child);
    return ValueListenableBuilder<bool>(
      valueListenable: navigator.userGestureInProgressNotifier,
      builder: (context, swiping, _) => SlideTransition(
        position: _followIn.animate(swiping ? animation : kAlwaysCompleteAnimation),
        child: SlideTransition(
          position: _followOut.animate(swiping ? secondaryAnimation : kAlwaysDismissedAnimation),
          child: builder(
            context,
            swiping ? kAlwaysCompleteAnimation : animation,
            swiping ? kAlwaysDismissedAnimation : secondaryAnimation,
            child,
          ),
        ),
      ),
    );
  }
}

/// פס צר בקצה השמאלי של המסך: גרירה ממנו ימינה מושכת את המסך הצידה,
/// ושחרור אחרי חצי מסך (או בתנופה מהירה) חוזר למסך הקודם. אחרת המסך חוזר
/// למקומו. פועל רק כשיש לאן לחזור ([ModalRoute.popGestureEnabled]).
class _SwipeBackDetector extends StatefulWidget {
  final Widget child;

  const _SwipeBackDetector({required this.child});

  @override
  State<_SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<_SwipeBackDetector> {
  static const _edgeWidth = 28.0;

  late final HorizontalDragGestureRecognizer _drag;
  ModalRoute<dynamic>? _route;
  bool _active = false;
  double _value = 1;

  @override
  void initState() {
    super.initState();
    _drag = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _onStart
      ..onUpdate = _onUpdate
      ..onEnd = _onEnd
      ..onCancel = _onCancel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final route = _route;
    if (route != null && route.isCurrent && route.popGestureEnabled) _drag.addPointer(event);
  }

  void _onStart(DragStartDetails details) {
    final route = _route;
    if (route == null || !route.isCurrent) return;
    _active = true;
    _value = 1;
    route.handleStartBackGesture(progress: 1);
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!_active) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    _value = (_value - details.primaryDelta! / width).clamp(0.0, 1.0);
    _route?.handleUpdateBackGestureProgress(progress: _value);
  }

  void _onEnd(DragEndDetails details) {
    if (!_active) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final velocity = details.velocity.pixelsPerSecond.dx / width;
    final back = velocity > 1 || (velocity > -1 && _value < 0.5);
    back ? _commit() : _onCancel();
  }

  void _onCancel() {
    if (!_active) return;
    _active = false;
    _route?.handleCancelBackGesture();
  }

  /// חוזרים אחורה מהנקודה שבה האצבע עזבה (בלי לקפוץ חזרה להתחלה), ומסמנים
  /// את סוף ההחלקה רק כשאנימציית היציאה מסתיימת.
  void _commit() {
    _active = false;
    final route = _route;
    final navigator = route?.navigator;
    final animation = route?.animation;
    if (route == null || navigator == null || animation == null) return;
    navigator.pop();
    if (animation.isAnimating) {
      late final AnimationStatusListener listener;
      listener = (status) {
        if (status.isAnimating) return;
        navigator.didStopUserGesture();
        animation.removeStatusListener(listener);
      };
      animation.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final edge = _edgeWidth + MediaQuery.paddingOf(context).left;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: edge,
          child: Listener(onPointerDown: _onPointerDown, behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}

/// מעברי ברירת המחדל לכל הפלטפורמות (ראו AppTheme). גם באייפון בלי
/// CupertinoPageTransitionsBuilder - הוא מוסיף החלקה מהקצה אחורה.
const kPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
  },
);
