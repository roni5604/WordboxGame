import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Loads the Firebase Analytics JS module on the web, without blocking the
/// rest of Firebase.
///
/// Why: firebase_core_web normally injects every plugin's JS module inside
/// `Firebase.initializeApp` and waits for all of them. Ad blockers often block
/// `firebase-analytics.js`; the import then never resolves and Auth/Firestore
/// (and multiplayer) would hang too. web/index.html therefore sets
/// `window.flutterfire_ignore_scripts = ['analytics']` and defines
/// `window.wordboxLoadAnalytics(version)`, which imports the module from the
/// same CDN/version as firebase_core and exposes it as
/// `window.firebase_analytics` (the global firebase_analytics_web reads).
/// If it fails, analytics silently stays off and the game works as before.
Future<bool> ensureWebAnalyticsLoaded() async {
  try {
    if (globalContext.has('firebase_analytics')) return true;
    final core = globalContext.getProperty<JSObject?>('firebase_core'.toJS);
    final version = core?.getProperty<JSString?>('SDK_VERSION'.toJS)?.toDart;
    if (version == null || version.isEmpty) return false;
    if (!globalContext.has('wordboxLoadAnalytics')) return false;
    final promise = globalContext.callMethod<JSPromise<JSBoolean>>('wordboxLoadAnalytics'.toJS, version.toJS);
    final ok = await promise.toDart.timeout(const Duration(seconds: 10));
    return ok.toDart && globalContext.has('firebase_analytics');
  } catch (e) {
    debugPrint('[analytics] web loader failed: $e');
    return false;
  }
}
