import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/notifications/push_message.dart';
import 'package:wordbox_hebrew/core/notifications/social_notification_keys.dart';

void main() {
  group('SocialNotificationKey', () {
    // אותן דוגמאות בדיוק כמו ב-functions/src/keys.test.ts - ככה ה-push מהשרת
    // וההתראה המקומית מקבלים אותו מזהה ומחליפים זה את זה.
    test('stableHash matches the TypeScript implementation (FNV-1a 32-bit)', () {
      expect(SocialNotificationKey.stableHash(''), 2166136261);
      expect(SocialNotificationKey.stableHash('a'), 3826002220);
      expect(SocialNotificationKey.stableHash('invite:abc123'), 1837784190);
      expect(SocialNotificationKey.stableHash('friend:alice_bob'), 4194507075);
      expect(SocialNotificationKey.stableHash('daily:uid42:2026-10-17'), 971645957);
      expect(SocialNotificationKey.stableHash('הזמנה'), 1095166462);
    });

    test('ids and tags per event type', () {
      final invite = SocialNotificationKey.invite('Xy7Qk');
      expect(invite.id, 2878);
      expect(invite.tag, 'invite-Xy7Qk');

      final request = SocialNotificationKey.friendRequest('alice_bob');
      expect(request.id, 3075);
      expect(request.tag, 'friend-alice_bob');

      final daily = SocialNotificationKey.dailyBeaten('bob', '2026-10-17');
      expect(daily.id, 4468);
      expect(daily.tag, 'daily-bob-2026-10-17');
    });
  });

  group('PushMessage', () {
    test('parses a server message', () {
      final push = PushMessage.fromData(
        {'type': 'dailyBeaten', 'route': '/daily', 'nid': '4468', 'tag': 'daily-bob-2026-10-17'},
        title: '🏆 בוב עקף/ה אתכם',
        body: '120 מול 90',
      );
      expect(push.type, PushType.dailyBeaten);
      expect(push.route, '/daily');
      expect(push.key.id, 4468);
      expect(push.key.tag, 'daily-bob-2026-10-17');
      expect(push.showInForeground, isTrue);
    });

    test('invites and friend requests are left to the in-game UI in the foreground', () {
      expect(PushMessage.fromData({'type': 'invite'}, title: 't').showInForeground, isFalse);
      expect(PushMessage.fromData({'type': 'friendRequest'}, title: 't').showInForeground, isFalse);
      expect(PushMessage.fromData({'type': 'something-new'}, title: 't').showInForeground, isFalse);
    });

    test('only in-app routes are accepted', () {
      expect(PushMessage.safeRoute('/friends?tab=1'), '/friends?tab=1');
      expect(PushMessage.safeRoute('https://evil.example'), isNull);
      expect(PushMessage.safeRoute('//evil.example/x'), isNull);
      expect(PushMessage.safeRoute(r'/\evil.example'), isNull);
      expect(PushMessage.safeRoute(42), isNull);
      expect(PushMessage.safeRoute(null), isNull);
    });

    test('out-of-range ids and bad tags fall back to safe values', () {
      final push = PushMessage.fromData({'type': 'dailyBeaten', 'nid': '1001', 'tag': ''});
      expect(push.key.id, 4999);
      expect(push.key.tag, 'push');
    });
  });
}
