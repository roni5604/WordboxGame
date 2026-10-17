import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/firebase_bootstrap.dart';
import '../../data/services/push_device_store.dart';
import '../config/app_config.dart';
import 'messaging_web_loader_stub.dart' if (dart.library.js_interop) 'messaging_web_loader_web.dart';
import 'notification_service.dart';
import 'push_message.dart';

/// Push מהשרת (Firebase Cloud Messaging): הזמנות למשחק, בקשות חברות וחבר/ה
/// שעקף/ה אותי באתגר היומי - מגיעים גם כשהאפליקציה סגורה לגמרי.
///
/// - המכשיר נרשם תחת `players/{uid}/devices/{token}` רק כשיש משתמש/ת
///   מחובר/ת, ההתראות מופעלות בהגדרות, ויש הרשאה של המערכת (אותה הרשאה
///   שמבקשים ב-[NotificationService.requestPermission]).
/// - כיבוי ההתראות בהגדרות או התנתקות מוחקים את הרישום ([sync], [forgetDevice]).
/// - את השליחה עצמה עושות פונקציות ענן (functions/src/index.ts).
///
/// הכול "הכי טוב שאפשר": בלי Firebase, בלי הרשאה או בלי רשת - פשוט לא
/// נרשמים, והמשחק ממשיך כרגיל (וההתראות המקומיות של social_host.dart עדיין
/// עובדות כשהאפליקציה ברקע).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  /// "uid|token" של הרישום האחרון ממכשיר זה - כדי למחוק אותו כשהטוקן
  /// מתחלף, כשמכבים התראות, או לפני התנתקות.
  static const _registeredKey = 'push_registered_device';

  bool _started = false;
  String? _uid;
  Future<void> _queue = Future.value();

  static bool get platformSupported {
    if (kIsWeb) return AppConfig.webPushVapidKey.isNotEmpty;
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  PushDeviceStore get _store => PushDeviceStore(FirebaseFirestore.instance);

  Future<void> start() async {
    if (_started || !platformSupported || !isFirebaseBackendReady()) return;
    try {
      if (!await ensureWebMessagingLoaded()) return;
      final messaging = FirebaseMessaging.instance;
      if (!await messaging.isSupported()) return;
      _started = true;

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => NotificationService.instance.openFromPush(PushMessage.fromData(m.data).route),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        NotificationService.instance.openFromPush(PushMessage.fromData(initial.data).route, launch: true);
      }

      messaging.onTokenRefresh.listen((_) => sync());
      FirebaseAuth.instance.authStateChanges().listen((user) {
        _uid = user?.uid;
        sync();
      });
    } catch (e) {
      debugPrint('Push init skipped: $e');
    }
  }

  /// מיישר את הרישום למצב הנוכחי (משתמש/ת, מתג ההתראות, הרשאת מערכת).
  /// קוראים לזה אחרי שינוי בהגדרות או אחרי שההרשאה ניתנה.
  Future<void> sync() => _serial(_sync);

  /// לפני התנתקות: מוחקים את הרישום כל עוד יש הרשאה לכתוב למסמך, ומבטלים
  /// את הטוקן כדי שמי שיתחבר/תתחבר אחר כך במכשיר לא יקבל התראות שלי.
  /// לא מחכים יותר מכמה שניות - התנתקות לא נתקעת בגלל רשת איטית.
  Future<void> forgetDevice() => _serial(() async {
        if (!_started) return;
        final previous = await _readRegistered();
        await _writeRegistered(null);
        if (previous != null && previous.uid == FirebaseAuth.instance.currentUser?.uid) {
          try {
            await _store.remove(uid: previous.uid, token: previous.token).timeout(const Duration(seconds: 3));
          } catch (_) {
            // בלי רשת: מבטלים את הטוקן למטה, והשרת ימחק את הרישום בשליחה הבאה.
          }
        }
        await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 3));
      }).timeout(const Duration(seconds: 6), onTimeout: () {});

  /// פעולה אחת בכל פעם. כתיבה ל-Firestore בלי רשת לא מסתיימת עד שהשרת
  /// מאשר, אז מגבילים בזמן - שלא תתקע את התור (ואת ההתנתקות).
  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task().timeout(const Duration(seconds: 20))).catchError((Object e) {
      debugPrint('Push registration failed: $e');
    });
    _queue = next;
    return next;
  }

  Future<void> _sync() async {
    if (!_started) return;
    final uid = _uid;
    final notifications = NotificationService.instance;
    final wanted = uid != null && await notifications.isEnabled() && await notifications.hasPermission();
    final previous = await _readRegistered();

    if (!wanted) {
      // מתג כבוי / אין הרשאה: מוחקים את הרישום שלי. (אחרי התנתקות כבר אי
      // אפשר - בשביל זה יש [forgetDevice] לפני היציאה.)
      if (previous != null && previous.uid == uid) {
        await _store.remove(uid: previous.uid, token: previous.token);
        await _writeRegistered(null);
      }
      return;
    }

    final token = await _getToken();
    if (token == null) return;
    if (previous != null && previous.uid == uid && previous.token != token) {
      await _store.remove(uid: uid, token: previous.token);
    }
    // גם אם כבר רשום: מרעננים את updatedAt פעם בהפעלה, כדי שאפשר יהיה
    // לנקות בעתיד מכשירים שלא נפתחו הרבה זמן.
    await _store.register(uid: uid, token: token, platform: _platformName);
    await _writeRegistered((uid: uid, token: token));
  }

  Future<String?> _getToken() async {
    final messaging = FirebaseMessaging.instance;
    if (kIsWeb) return messaging.getToken(vapidKey: AppConfig.webPushVapidKey);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // ב-iOS אין טוקן FCM לפני שמגיע טוקן APNs (אחרי ההרשמה של המערכת).
      for (var i = 0; i < 6; i++) {
        if (await messaging.getAPNSToken() != null) break;
        if (i == 5) return null;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return messaging.getToken();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final push = PushMessage.fromData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    if (!push.showInForeground) return;
    NotificationService.instance.showSocial(key: push.key, title: push.title!, body: push.body ?? '', route: push.route);
  }

  Future<({String uid, String token})?> _readRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_registeredKey);
      final split = value?.indexOf('|') ?? -1;
      if (value == null || split <= 0) return null;
      return (uid: value.substring(0, split), token: value.substring(split + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRegistered(({String uid, String token})? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_registeredKey);
      } else {
        await prefs.setString(_registeredKey, '${value.uid}|${value.token}');
      }
    } catch (_) {}
  }
}
