import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// התראות דפדפן (Notification API). באתר אין תזמון מראש בלי שרת push, אז
/// משתמשים בהן רק כשהלשונית ברקע ומשהו קורה עכשיו (הזמנה למשחק, בקשת חברות).
bool get browserNotificationsSupported {
  try {
    return web.window.has('Notification');
  } catch (_) {
    return false;
  }
}

/// 'granted' / 'denied' / 'default', או 'unsupported'.
String browserNotificationPermission() {
  if (!browserNotificationsSupported) return 'unsupported';
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// חייב לרוץ מתוך לחיצה של המשתמש/ת (דפדפנים חוסמים בקשה בלי מחווה).
Future<bool> requestBrowserNotificationPermission() async {
  if (!browserNotificationsSupported) return false;
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

bool get browserTabHidden {
  try {
    return web.document.hidden;
  } catch (_) {
    return false;
  }
}

void showBrowserNotification({
  required String title,
  required String body,
  required String tag,
  void Function()? onClick,
}) {
  if (browserNotificationPermission() != 'granted') return;
  try {
    final notification = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: tag, icon: 'icons/Icon-192.png', lang: 'he', dir: 'rtl'),
    );
    notification.onclick = ((web.Event _) {
      web.window.focus();
      notification.close();
      onClick?.call();
    }).toJS;
  } catch (_) {
    // דפדפן שלא מאפשר יצירת Notification מהדף (למשל אנדרואיד כרום) - מוותרים בשקט.
  }
}
