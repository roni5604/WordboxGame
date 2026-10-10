import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/web_safe_area.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/pressable.dart';
import 'features/social/social_host.dart';
import 'providers/sound_provider.dart';

/// ה-App Widget הראשי: עברית כברירת מחדל, כיווניות RTL, ו-go_router
/// כמנוע הניווט המשותף לנייד ולאתר.
class WordboxApp extends ConsumerStatefulWidget {
  const WordboxApp({super.key});

  @override
  ConsumerState<WordboxApp> createState() => _WordboxAppState();
}

class _WordboxAppState extends ConsumerState<WordboxApp> {
  @override
  void initState() {
    super.initState();
    // כל לחיצה על כפתור באפליקציה משמיעה את אותו "טאפ" עדין.
    PressFeedback.onPress = () => ref.read(soundServiceProvider).playButtonTap();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'מצא ת׳מילה',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
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
