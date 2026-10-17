import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/player_profile.dart';
import 'browser_notifications_stub.dart' if (dart.library.js_interop) 'browser_notifications_web.dart' as browser;
import 'reminder_planner.dart';
import 'social_notification_keys.dart';

/// התראות למשתמש/ת:
///
/// - **iOS / Android**: תזכורות מקומיות מתוזמנות ([ReminderPlanner]) - בונוס
///   יומי, רצף אתגר יומי, וחזרה אחרי הפסקה. מתוזמנות מחדש בכל פעם שהאפליקציה
///   יוצאת לרקע, בלי שרת.
/// - **כל הפלטפורמות**: התראה מיידית כשמגיעה הזמנה למשחק או בקשת חברות
///   בזמן שהאפליקציה/הלשונית ברקע ([showSocial]). באתר דרך Notification API
///   של הדפדפן.
/// - **Push מהשרת** (push_service.dart): מגיע גם כשהאפליקציה סגורה, באותם
///   ערוצים ועם אותם מזהים ([SocialNotificationKey]), כך שאין כפילויות.
///
/// כל הפעולות בטוחות לקריאה גם לפני [init] או כשאין תמיכה - הן פשוט לא
/// עושות כלום (כך גם בבדיקות).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _enabledKey = 'notifications_enabled';
  static const _promptedKey = 'notifications_prompted';

  /// מאיזה שלב מציעים להפעיל התראות (אחרי שלבי ההדרכה, כשכבר ברור שהמשחק מעניין).
  static const int askAfterLevel = 4;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String route)? _onOpenRoute;

  static bool get _nativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get isSupported => kIsWeb ? browser.browserNotificationsSupported : _nativeSupported;

  /// באתר אין תזכורות מתוזמנות (צריך שרת push) - רק התראות מיידיות.
  bool get canSchedule => _initialized && _nativeSupported;

  Future<void> init({void Function(String route)? onOpenRoute}) async {
    _onOpenRoute = onOpenRoute;
    if (_initialized || !isSupported) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      tzdata.initializeTimeZones();
      try {
        final local = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(local.identifier));
      } catch (_) {
        // אזור זמן לא מוכר - המשחק בעברית, אז ישראל היא ברירת מחדל סבירה.
        tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
          // את ההרשאה מבקשים רק אחרי הסבר במשחק (ראו [requestPermission]).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload),
      );
      _initialized = true;
      await _createAndroidChannels();
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _pendingLaunchRoute = launch?.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('Notifications init skipped: $e');
    }
  }

  /// ב-Android הערוץ נוצר רק כשמוצגת בו התראה ראשונה - אבל push מהשרת
  /// מגיע לערוץ 'social' גם לפני שהאפליקציה הציגה בו משהו, אז יוצרים מראש.
  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final details in [_reminderDetails.android!, _socialAndroid()]) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        details.channelId,
        details.channelName,
        description: details.channelDescription,
        importance: details.importance,
      ));
    }
  }

  String? _pendingLaunchRoute;
  bool _launchRouteTaken = false;

  /// אם האפליקציה נפתחה מלחיצה על התראה - המסך שאליו היא מובילה (פעם אחת).
  String? takeLaunchRoute() {
    _launchRouteTaken = true;
    final route = _pendingLaunchRoute;
    _pendingLaunchRoute = null;
    return route;
  }

  /// לחיצה על push מהשרת. [launch] - ההתראה היא שפתחה את האפליקציה: אם
  /// מסך הבית עוד לא עלה, הוא ינווט לשם בעצמו ([takeLaunchRoute]).
  void openFromPush(String? route, {bool launch = false}) {
    if (launch && !_launchRouteTaken) {
      if (route != null && route.startsWith('/')) _pendingLaunchRoute = route;
      return;
    }
    _open(route);
  }

  void _open(String? route) {
    if (route == null || route.isEmpty || !route.startsWith('/')) return;
    _onOpenRoute?.call(route);
  }

  /// ההגדרה בתוך המשחק (מתג "התראות" בהגדרות). ברירת המחדל: מופעל, אבל
  /// בפועל צריך גם הרשאה של המערכת.
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    if (!value) await cancelReminders();
  }

  Future<bool> hasPermission() async {
    if (!_initialized) return false;
    if (kIsWeb) return browser.browserNotificationPermission() == 'granted';
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// מבקש הרשאה מהמערכת. באתר חייב לרוץ מתוך לחיצה.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    if (kIsWeb) return browser.requestBrowserNotificationPermission();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: false, sound: true) ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: false, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  /// האם להציג עכשיו את ההצעה להפעיל התראות (פעם אחת, אחרי ההדרכה).
  Future<bool> shouldOfferPermission(PlayerProfile profile) async {
    if (!_initialized || profile.highestUnlockedLevel < askAfterLevel) return false;
    if (kIsWeb && browser.browserNotificationPermission() != 'default') return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptedKey) ?? false) return false;
    } catch (_) {
      return false;
    }
    if (!await isEnabled()) return false;
    return !await hasPermission();
  }

  Future<void> markOffered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promptedKey, true);
    } catch (_) {}
  }

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'תזכורות',
      channelDescription: 'בונוס יומי, רצף האתגר היומי ותזכורת לחזור לשחק',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_stat_notify',
      color: Color(0xFFFF7A45),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'reminders'),
    macOS: DarwinNotificationDetails(threadIdentifier: 'reminders'),
  );

  /// ערוץ 'social' - גם ה-push מהשרת נשלח אליו (functions/src/messages.ts).
  static AndroidNotificationDetails _socialAndroid({String? tag}) => AndroidNotificationDetails(
        'social',
        'חברים והזמנות',
        channelDescription: 'הזמנות למשחק, בקשות חברות ותוצאות של חברים',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
        color: const Color(0xFF7B3FF2),
        tag: tag,
      );

  static NotificationDetails _socialDetails(SocialNotificationKey key) => NotificationDetails(
        android: _socialAndroid(tag: key.tag),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'social', interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: const DarwinNotificationDetails(threadIdentifier: 'social'),
      );

  /// מבטל את התזכורות הקודמות ומתזמן מחדש לפי המצב הנוכחי.
  Future<void> reschedule(PlayerProfile profile, {required bool isGuest, DateTime? now}) async {
    if (!canSchedule) return;
    try {
      await cancelReminders();
      if (!await isEnabled() || !await hasPermission()) return;
      for (final r in ReminderPlanner.plan(profile, now ?? DateTime.now(), isGuest: isGuest)) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: _reminderDetails,
          // בלי הרשאת "שעון מעורר מדויק": דקה-שתיים של סטייה לא משנות לתזכורת.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
          payload: r.route,
        );
      }
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  Future<void> cancelReminders() async {
    if (!canSchedule) return;
    try {
      for (final id in ReminderPlanner.allIds) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {}
  }

  /// התראה מיידית על אירוע חברתי (הזמנה, בקשת חברות, חבר/ה שעקף/ה אותי).
  /// [key] זהה ל-push של אותו אירוע, כך שאם שניהם מגיעים רואים התראה אחת.
  Future<void> showSocial({
    required SocialNotificationKey key,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_initialized || !await isEnabled()) return;
    if (kIsWeb) {
      browser.showBrowserNotification(title: title, body: body, tag: key.tag, onClick: () => _open(route));
      return;
    }
    try {
      // ב-Android ה-push מוצג כ-(tag, 0), אז ההתראה המקומית באותו מקום בדיוק.
      final id = defaultTargetPlatform == TargetPlatform.android ? 0 : key.id;
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _socialDetails(key), payload: route);
    } catch (_) {}
  }

  /// באתר: האם הלשונית מוסתרת כרגע (אז כדאי להתריע).
  bool get webTabHidden => kIsWeb && browser.browserTabHidden;
}
