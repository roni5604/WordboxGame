/// מחוץ לדפדפן אין Notification API - הכל no-op (ראו browser_notifications_web.dart).
bool get browserNotificationsSupported => false;

String browserNotificationPermission() => 'unsupported';

Future<bool> requestBrowserNotificationPermission() async => false;

bool get browserTabHidden => false;

void showBrowserNotification({
  required String title,
  required String body,
  required String tag,
  void Function()? onClick,
}) {}
