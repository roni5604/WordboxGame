import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/ads/ads_runtime.dart';
import 'core/analytics/analytics_service.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/ui/game_backdrop.dart';
import 'data/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // מסך מלא "מקצה לקצה": הרקע של המשחק ממשיך מאחורי שורת הסטטוס וה-notch
  // / Dynamic Island למעלה, ומאחורי פס הבית / כפתורי הניווט למטה. התוכן
  // עצמו נשאר באזור הבטוח (SafeArea / GameScaffold).
  if (!kIsWeb) {
    // המשחק מעוצב לטלפון בעמידה בלבד.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(kLightSystemBars);
  }

  await Hive.initFlutter();

  if (AppConfig.useFirebaseBackend) {
    try {
      await bootstrapFirebase();
    } catch (e) {
      // Firebase לא הוגדר כראוי עדיין - ממשיכים במצב מקומי בלבד כדי שהמשחק
      // לעולם לא יקרוס עבור שחקן קצה עקב תצורת backend חסרה.
      debugPrint('Firebase bootstrap skipped: $e');
    }
  }

  // התראות: לחיצה על התראה פותחת את המסך שלה (בונוס יומי, אתגר, מפה...).
  unawaited(NotificationService.instance.init(onOpenRoute: (route) => appRouter.go(route)));

  // Analytics (GA4): no-op when Firebase is off or failed to initialize.
  // Must run before the ads/UMP flow below so the consent result reaches it.
  unawaited(AnalyticsService.instance.init());

  // באתר מתחילים לטעון את תג הפרסומת לפני הפריים הראשון, כדי ש-Google
  // יחבר את adBreak לפני שהמשחק עולה. במובייל מחכים לפריים: טופס ההסכמה
  // צריך מסך פעיל.
  if (kIsWeb) {
    unawaited(AdsRuntime.ensureInitialized());
  }
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await AdsRuntime.ensureInitialized();
    } catch (e) {
      debugPrint('Ads init skipped: $e');
    }
  });

  runApp(const ProviderScope(child: WordboxApp()));
}
