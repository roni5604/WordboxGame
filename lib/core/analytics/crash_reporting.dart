import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/firebase_bootstrap.dart';

/// דיווח קריסות (Firebase Crashlytics) - iOS ו-Android בלבד.
///
/// * לא עושה כלום באתר, כש-Firebase כבוי או לא אותחל, ובבדיקות ([init] נקרא
///   רק מ-main.dart).
/// * בבילד debug האיסוף כבוי - רק release מדווח.
/// * לא זורק לעולם, ולא שולח מידע אישי: מזהה המשתמש הוא ה-uid של Firebase.
class CrashReporting {
  CrashReporting._();

  static FirebaseCrashlytics? _crashlytics;

  static bool get _supportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  /// נקרא פעם אחת אחרי אתחול Firebase: שגיאות Flutter ושגיאות אסינכרוניות
  /// שלא נתפסו נרשמות כקריסות.
  static Future<void> init() async {
    if (!_supportedPlatform || !isFirebaseBackendReady()) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
      _crashlytics = crashlytics;
    } catch (e) {
      debugPrint('[crashlytics] disabled: $e');
    }
  }

  /// שגיאה שטופלה אבל כדאי לדעת עליה (למשל כשל בביטול טוקן של Apple).
  static void recordNonFatal(Object error, {StackTrace? stack, String? reason}) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return;
    unawaited(crashlytics.recordError(error, stack ?? StackTrace.current, reason: reason).catchError((_) {}));
  }

  /// uid של Firebase בלבד (אורחים כלולים), או ריק בהתנתקות.
  static void setUserId(String? uid) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return;
    unawaited(crashlytics.setUserIdentifier(uid ?? '').catchError((_) {}));
  }
}
