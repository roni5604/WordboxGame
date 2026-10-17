import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// טוען את firebase-messaging.js באתר רק כשצריך push.
///
/// בדיוק כמו Analytics (analytics_web_loader_web.dart): firebase_core_web
/// מחכה לכל המודולים בתוך Firebase.initializeApp, ומודול שנחסם (חוסם
/// פרסומות, רשת מסוננת) היה תוקע גם את Auth/Firestore. לכן web/index.html
/// מדלג עליו (`flutterfire_ignore_scripts`) וטוען אותו כאן, מאותו CDN ובאותה
/// גרסה, אל `window.firebase_messaging` (המשתנה ש-firebase_messaging_web קורא).
Future<bool> ensureWebMessagingLoaded() async {
  try {
    if (globalContext.has('firebase_messaging')) return true;
    final core = globalContext.getProperty<JSObject?>('firebase_core'.toJS);
    final version = core?.getProperty<JSString?>('SDK_VERSION'.toJS)?.toDart;
    if (version == null || version.isEmpty) return false;
    if (!globalContext.has('wordboxLoadMessaging')) return false;
    final promise = globalContext.callMethod<JSPromise<JSBoolean>>('wordboxLoadMessaging'.toJS, version.toJS);
    final ok = await promise.toDart.timeout(const Duration(seconds: 10));
    return ok.toDart && globalContext.has('firebase_messaging');
  } catch (e) {
    debugPrint('[push] web loader failed: $e');
    return false;
  }
}
