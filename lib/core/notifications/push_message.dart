import 'social_notification_keys.dart';

/// סוגי ה-push שהשרת שולח (functions/src/messages.ts).
enum PushType { invite, friendRequest, dailyBeaten, unknown }

/// השדות ב-`data` של הודעת push מהשרת, אחרי בדיקה. ההודעה מגיעה מבחוץ,
/// אז לא סומכים על הערכים: מסך רק בתוך האפליקציה, ומזהה התראה בטווח.
class PushMessage {
  final PushType type;
  final String? route;
  final SocialNotificationKey key;
  final String? title;
  final String? body;

  const PushMessage({required this.type, required this.route, required this.key, this.title, this.body});

  factory PushMessage.fromData(Map<String, dynamic> data, {String? title, String? body}) {
    final type = switch (data['type']) {
      'invite' => PushType.invite,
      'friendRequest' => PushType.friendRequest,
      'dailyBeaten' => PushType.dailyBeaten,
      _ => PushType.unknown,
    };
    final id = int.tryParse('${data['nid'] ?? ''}');
    final tag = data['tag'];
    return PushMessage(
      type: type,
      route: safeRoute(data['route']),
      key: SocialNotificationKey(
        id != null && id >= SocialNotificationKey.inviteBase && id < 5000 ? id : 4999,
        tag is String && tag.isNotEmpty && tag.length <= 200 ? tag : 'push',
      ),
      title: title,
      body: body,
    );
  }

  /// הזמנות ובקשות חברות כבר מוצגות בחלון/הודעה בתוך המשחק כשהוא פתוח
  /// (social_host.dart), אז push שלהן בחזית מיותר. את השאר מציגים כהתראה.
  bool get showInForeground => type == PushType.dailyBeaten && title != null;

  /// נתיב פנימי בלבד ("/friends?tab=1"), לא כתובת חיצונית ולא "//host".
  static String? safeRoute(Object? value) {
    if (value is! String || value.length > 200) return null;
    if (!value.startsWith('/') || value.startsWith('//') || value.contains('\\')) return null;
    return value;
  }
}
