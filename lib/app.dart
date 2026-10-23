import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/platform/web_safe_area.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_scroll_behavior.dart';
import 'core/ui/pressable.dart';
import 'features/game/widgets/grid_board.dart';
import 'features/game/widgets/pause_menu.dart';
import 'features/social/social_host.dart';
import 'providers/auth_provider.dart';
import 'providers/player_profile_provider.dart';
import 'providers/sound_provider.dart';
import 'core/feedback/haptics.dart';

/// ה-App Widget הראשי: עברית כברירת מחדל, כיווניות RTL, ו-go_router
/// כמנוע הניווט המשותף לנייד ולאתר.
class WordboxApp extends ConsumerStatefulWidget {
  const WordboxApp({super.key});

  @override
  ConsumerState<WordboxApp> createState() => _WordboxAppState();
}

class _WordboxAppState extends ConsumerState<WordboxApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // תזכורות מקומיות: מתוזמנות מחדש פעם אחת כשהפרופיל נטען (מבטל תזכורת
    // ישנה שכבר לא רלוונטית), ושוב בכל יציאה לרקע - ראו didChangeAppLifecycleState.
    ref.listenManual(playerProfileProvider, (previous, next) {
      if (previous?.valueOrNull == null && next.valueOrNull != null) _rescheduleReminders();
    }, fireImmediately: true);
    // כל לחיצה על כפתור באפליקציה משמיעה את אותו "טאפ" עדין.
    // באתר - הלחיצה הראשונה היא גם הרגע שמותר בו להתחיל את מוזיקת הרקע.
    PressFeedback.onPress = () {
      ref.read(soundServiceProvider).playButtonTap();
      ref.read(musicServiceProvider).userInteracted();
    };
    // כל אות שמחברים על הלוח עולה צליל אחד בסולם, ורטט שמתחזק עם אורך המילה.
    GridBoard.onTileAdded = (index) {
      ref.read(soundServiceProvider).playTileTap(index);
      ref.read(musicServiceProvider).userInteracted();
    };
    // ספירה לאחור לפני משחק (3-2-1-יאללה) עם ג'ינגל מסונכרן.
    StartCountdown.onStart = () => ref.read(soundServiceProvider).playCountdown();
    // מוזיקת הרקע מתחילה ברגע שהפרופיל נטען (אם היא מופעלת בהגדרות).
    ref.read(musicServiceProvider);
    // הגדרת "רטט" בפרופיל קובעת את כל הרטט באפליקציה (גם באתר).
    ref.listenManual(
      playerProfileProvider,
      (previous, next) => Haptics.enabled = next.valueOrNull?.hapticsOn ?? true,
      fireImmediately: true,
    );
    // Analytics identity: user id = Firebase uid (null after sign-out),
    // auth_method, and the max_level / current_world user properties.
    final analytics = ref.read(analyticsProvider);
    ref.listenManual(authStateProvider, (previous, next) {
      if (next.isLoading) return;
      analytics.setAuthUser(next.valueOrNull);
    }, fireImmediately: true);
    ref.listenManual(playerProfileProvider, (previous, next) {
      final profile = next.valueOrNull;
      if (profile != null) analytics.setProgress(highestUnlockedLevel: profile.highestUnlockedLevel);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // מוזיקה נעצרת כשהאפליקציה ברקע (inactive = רגע מעבר, למשל מרכז הבקרה - ממשיכים).
    ref.read(musicServiceProvider).foreground =
        state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _rescheduleReminders();
  }

  void _rescheduleReminders() {
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    NotificationService.instance.reschedule(profile, isGuest: user == null || user.isAnonymous);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'מצא ת׳מילה',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return WebSafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SocialHost(
              router: appRouter,
              navigatorKey: rootNavigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
