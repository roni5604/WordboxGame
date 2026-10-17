// בדיקות ללוגיקה של ה-push (בלי Firebase): npm test
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import type { BatchResponse, MulticastMessage } from 'firebase-admin/messaging';

import { beatenFriends, scoreRaise } from './daily.js';
import { dailyBeatenKey, friendRequestKey, inviteKey, stableHash } from './keys.js';
import { buildMessage, dailyBeatenContent, displayName, friendRequestContent, inviteContent } from './messages.js';
import { sendToUser, type DeviceStore } from './send.js';

describe('keys', () => {
  // אותן דוגמאות כמו ב-test/core/notifications/social_notification_keys_test.dart.
  test('stableHash matches the Dart implementation', () => {
    assert.equal(stableHash(''), 2166136261);
    assert.equal(stableHash('a'), 3826002220);
    assert.equal(stableHash('invite:abc123'), 1837784190);
    assert.equal(stableHash('friend:alice_bob'), 4194507075);
    assert.equal(stableHash('daily:uid42:2026-10-17'), 971645957);
    assert.equal(stableHash('הזמנה'), 1095166462);
  });

  test('ids and tags per event type', () => {
    assert.deepEqual(inviteKey('Xy7Qk'), { id: 2878, tag: 'invite-Xy7Qk' });
    assert.deepEqual(friendRequestKey('alice_bob'), { id: 3075, tag: 'friend-alice_bob' });
    assert.deepEqual(dailyBeatenKey('bob', '2026-10-17'), { id: 4468, tag: 'daily-bob-2026-10-17' });
  });
});

describe('messages', () => {
  const invite = { from: 'host', to: 'bob', fromName: 'רוני', gridSize: 5, status: 'pending' };

  test('invite content', () => {
    const content = inviteContent('i1', invite);
    assert.ok(content);
    assert.equal(content.title, '🎮 רוני מזמין/ה אתכם למשחק');
    assert.equal(content.body, 'לוח 5×5 · ההזמנה בתוקף לדקה. היכנסו עכשיו!');
    assert.equal(content.route, '/home');
    assert.equal(content.ttlSeconds, 60);
  });

  test('answered or malformed invites are not sent', () => {
    assert.equal(inviteContent('i1', { ...invite, status: 'accepted' }), null);
    assert.equal(inviteContent('i1', { ...invite, to: undefined }), null);
  });

  test('friend request content', () => {
    const content = friendRequestContent('alice_bob', { from: 'alice', to: 'bob', fromName: 'אליס' });
    assert.ok(content);
    assert.equal(content.body, 'אליס רוצה להיות חבר/ה שלכם');
    assert.equal(content.route, '/friends?tab=1');
    assert.deepEqual(content.key, friendRequestKey('alice_bob'));
  });

  test('names are cleaned of control/bidi characters and have a fallback', () => {
    assert.equal(displayName('‮רוני\n'), 'רוני');
    assert.equal(displayName(''), 'חבר/ה');
    assert.equal(displayName(42), 'חבר/ה');
    assert.equal([...displayName('א'.repeat(100))].length, 40);
  });

  test('FCM message carries the same tag/id as the local notification', () => {
    const content = dailyBeatenContent({ uid: 'alice', name: 'אליס', score: 120 }, 90, '2026-10-17');
    const message = buildMessage(content, { webAppUrl: 'https://wordbox-64b19.web.app', nowMs: 1_700_000_000_000 });
    const key = dailyBeatenKey('alice', '2026-10-17');

    assert.deepEqual(message.data, { type: 'dailyBeaten', route: '/daily', tag: key.tag, nid: String(key.id) });
    assert.equal(message.notification?.body, '120 נקודות מול 90 שלכם. מחר יש אתגר חדש - הזדמנות לנקום 😉');
    assert.equal(message.android?.notification?.tag, key.tag);
    assert.equal(message.android?.notification?.channelId, 'social');
    assert.equal(message.apns?.headers?.['apns-collapse-id'], String(key.id));
    assert.equal(message.apns?.headers?.['apns-expiration'], String(1_700_000_000 + 12 * 3600));
    assert.equal(message.webpush?.notification?.tag, key.tag);
    assert.equal(message.webpush?.fcmOptions?.link, 'https://wordbox-64b19.web.app/daily');
  });

  test('web link keeps the query string', () => {
    const content = friendRequestContent('a_b', { to: 'b', fromName: 'a' });
    assert.ok(content);
    const message = buildMessage(content, { webAppUrl: 'https://wordbox-64b19.web.app', nowMs: 0 });
    assert.equal(message.webpush?.fcmOptions?.link, 'https://wordbox-64b19.web.app/friends?tab=1');
  });
});

describe('daily rivalry', () => {
  test('a raise is detected only when today\'s score goes up', () => {
    assert.deepEqual(scoreRaise({ dailyDate: '2026-10-17', dailyScore: 0 }, { dailyDate: '2026-10-17', dailyScore: 80 }), {
      dateKey: '2026-10-17',
      previous: 0,
      current: 80,
    });
    // יום חדש מתחיל מאפס, גם אם אתמול היה ניקוד גבוה יותר.
    assert.deepEqual(scoreRaise({ dailyDate: '2026-10-16', dailyScore: 200 }, { dailyDate: '2026-10-17', dailyScore: 50 }), {
      dateKey: '2026-10-17',
      previous: 0,
      current: 50,
    });
    // דופק נוכחות - אין שינוי.
    assert.equal(scoreRaise({ dailyDate: '2026-10-17', dailyScore: 80 }, { dailyDate: '2026-10-17', dailyScore: 80 }), null);
    assert.equal(scoreRaise({}, { dailyDate: 'garbage', dailyScore: 80 }), null);
    assert.equal(scoreRaise({}, { dailyDate: '2026-10-17', dailyScore: -5 }), null);
  });

  test('only friends who played today and were just overtaken are notified', () => {
    const raise = { dateKey: '2026-10-17', previous: 40, current: 100 };
    const notified = beatenFriends(raise, [
      { uid: 'beaten', dailyDate: '2026-10-17', dailyScore: 70 },
      { uid: 'tied-before', dailyDate: '2026-10-17', dailyScore: 40 },
      { uid: 'still-ahead', dailyDate: '2026-10-17', dailyScore: 150 },
      { uid: 'tied-now', dailyDate: '2026-10-17', dailyScore: 100 },
      { uid: 'already-behind', dailyDate: '2026-10-17', dailyScore: 30 },
      { uid: 'yesterday', dailyDate: '2026-10-16', dailyScore: 70 },
      { uid: 'not-played', dailyDate: '2026-10-17', dailyScore: 0 },
    ]).map((f) => f.uid);
    assert.deepEqual(notified, ['beaten', 'tied-before']);
  });
});

describe('sendToUser', () => {
  function fakeStore(tokens: string[]) {
    const removed: string[] = [];
    const store: DeviceStore = {
      tokens: async () => tokens,
      remove: async (_uid, dead) => {
        removed.push(...dead);
      },
    };
    return { store, removed };
  }

  function sender(codes: Record<string, string | undefined>) {
    const calls: MulticastMessage[] = [];
    return {
      calls,
      async sendEachForMulticast(message: MulticastMessage): Promise<BatchResponse> {
        calls.push(message);
        const responses = message.tokens.map((t) =>
          codes[t]
            ? { success: false, error: { code: codes[t] } as never }
            : { success: true, messageId: `m-${t}` },
        );
        const successCount = responses.filter((r) => r.success).length;
        return { responses, successCount, failureCount: responses.length - successCount };
      },
    };
  }

  test('sends to every device and removes only dead tokens', async () => {
    const { store, removed } = fakeStore(['ok', 'gone', 'bad', 'apns-key-missing']);
    const fcm = sender({
      gone: 'messaging/registration-token-not-registered',
      bad: 'messaging/invalid-registration-token',
      'apns-key-missing': 'messaging/third-party-auth-error',
    });
    const result = await sendToUser(store, fcm, 'bob', { notification: { title: 't' } });
    assert.deepEqual(result, {
      sent: 1,
      failed: 3,
      removed: 2,
      errors: [
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
        'messaging/third-party-auth-error',
      ],
    });
    assert.deepEqual(removed, ['gone', 'bad']);
    assert.deepEqual(fcm.calls[0].tokens, ['ok', 'gone', 'bad', 'apns-key-missing']);
  });

  test('no devices - nothing is sent', async () => {
    const { store } = fakeStore([]);
    const fcm = sender({});
    assert.deepEqual(await sendToUser(store, fcm, 'bob', {}), { sent: 0, failed: 0, removed: 0, errors: [] });
    assert.equal(fcm.calls.length, 0);
  });

  test('more than 500 devices are sent in chunks', async () => {
    const tokens = Array.from({ length: 1201 }, (_, i) => `t${i}`);
    const { store } = fakeStore(tokens);
    const fcm = sender({});
    const result = await sendToUser(store, fcm, 'bob', {});
    assert.equal(result.sent, 1201);
    assert.deepEqual(fcm.calls.map((c) => c.tokens.length), [500, 500, 201]);
  });
});
