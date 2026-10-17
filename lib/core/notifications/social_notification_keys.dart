import 'dart:convert';

/// מזהה יציב של התראה חברתית: אותו אירוע (הזמנה, בקשת חברות, עקיפה באתגר
/// היומי) מקבל אותו [id] ואותו [tag] גם בהתראה המקומית שהאפליקציה מציגה
/// כשהיא ברקע (social_host.dart) וגם ב-push שהשרת שולח (functions/src/keys.ts).
///
/// ככה מערכת ההפעלה מחליפה התראה אחת בשנייה במקום להציג אותה פעמיים:
/// - Android: ה-push מוצג עם `tag` ומזהה 0, ולכן ההתראה המקומית משתמשת
///   באותו tag ובמזהה 0.
/// - iOS: ה-push נשלח עם `apns-collapse-id` = [id], וזה גם המזהה של ההתראה
///   המקומית.
/// - אתר: Notification API מחליף התראות עם אותו [tag].
///
/// שינוי כאן מחייב את אותו שינוי ב-functions/src/keys.ts (יש בדיקה עם אותן
/// דוגמאות בשני הצדדים).
class SocialNotificationKey {
  final int id;
  final String tag;

  const SocialNotificationKey(this.id, this.tag);

  static const int inviteBase = 2000;
  static const int friendRequestBase = 3000;
  static const int dailyBeatenBase = 4000;

  factory SocialNotificationKey.invite(String inviteId) =>
      SocialNotificationKey(inviteBase + stableHash('invite:$inviteId') % 1000, 'invite-$inviteId');

  factory SocialNotificationKey.friendRequest(String requestId) =>
      SocialNotificationKey(friendRequestBase + stableHash('friend:$requestId') % 1000, 'friend-$requestId');

  factory SocialNotificationKey.dailyBeaten(String friendUid, String dateKey) => SocialNotificationKey(
        dailyBeatenBase + stableHash('daily:$friendUid:$dateKey') % 1000,
        'daily-$friendUid-$dateKey',
      );

  /// FNV-1a של 32 ביט על בייטים של UTF-8 - זהה בדיוק למימוש ב-TypeScript
  /// (String.hashCode של Dart לא יציב בין הרצות ובין שפות). הכפל מפוצל
  /// לחצאים של 16 ביט כדי שלא יעבור 2^53 בקומפילציית Web.
  static int stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      final lo = hash & 0xffff;
      final hi = hash ~/ 0x10000;
      // FNV prime = 0x01000193 = 0x0100 * 2^16 + 0x0193.
      hash = (lo * 0x193 + ((hi * 0x193 + lo * 0x100) % 0x10000) * 0x10000) % 0x100000000;
    }
    return hash;
  }
}
