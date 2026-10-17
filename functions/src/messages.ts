// תוכן ההתראות ובניית הודעת FCM לכל הפלטפורמות. לוגיקה טהורה (נבדקת
// ב-messages.test.ts). הטקסטים זהים להתראות המקומיות ב-social_host.dart.
import type { MulticastMessage } from 'firebase-admin/messaging';

import { dailyBeatenKey, friendRequestKey, inviteKey, type NotificationKey } from './keys.js';

export type PushType = 'invite' | 'friendRequest' | 'dailyBeaten';

export interface PushContent {
  type: PushType;
  title: string;
  body: string;
  /** מסך בתוך האפליקציה שנפתח בלחיצה. */
  route: string;
  key: NotificationKey;
  /** אחרי כמה זמן כבר אין טעם למסור (הזמנה בתוקף לדקה). */
  ttlSeconds: number;
}

const FALLBACK_NAME = 'חבר/ה';

/** שם להצגה: בלי תווי בקרה/כיווניות, מקוצר, ועם ברירת מחדל. */
export function displayName(value: unknown): string {
  if (typeof value !== 'string') return FALLBACK_NAME;
  // eslint-disable-next-line no-control-regex
  const clean = value.replace(/[\u0000-\u001f\u007f‎‏‪-‮⁦-⁩]/g, '').trim();
  if (!clean) return FALLBACK_NAME;
  return [...clean].slice(0, 40).join('');
}

function intIn(value: unknown, lo: number, hi: number): number | null {
  return typeof value === 'number' && Number.isInteger(value) && value >= lo && value <= hi ? value : null;
}

/** הזמנה למשחק (invites/{id}) - רק כשהיא עדיין ממתינה. */
export function inviteContent(inviteId: string, invite: Record<string, unknown>): PushContent | null {
  if (invite.status !== 'pending' || typeof invite.to !== 'string') return null;
  const grid = intIn(invite.gridSize, 3, 8) ?? 4;
  return {
    type: 'invite',
    title: `🎮 ${displayName(invite.fromName)} מזמין/ה אתכם למשחק`,
    body: `לוח ${grid}×${grid} · ההזמנה בתוקף לדקה. היכנסו עכשיו!`,
    route: '/home',
    key: inviteKey(inviteId),
    ttlSeconds: 60,
  };
}

/** בקשת חברות (friendRequests/{from_to}). */
export function friendRequestContent(requestId: string, request: Record<string, unknown>): PushContent | null {
  if (typeof request.to !== 'string') return null;
  return {
    type: 'friendRequest',
    title: '💌 בקשת חברות חדשה',
    body: `${displayName(request.fromName)} רוצה להיות חבר/ה שלכם`,
    route: '/friends?tab=1',
    key: friendRequestKey(requestId),
    ttlSeconds: 7 * 24 * 3600,
  };
}

/** חבר/ה ([scorer]) עקף/ה אותי באתגר היומי. */
export function dailyBeatenContent(
  scorer: { uid: string; name: unknown; score: number },
  myScore: number,
  dateKey: string,
): PushContent {
  return {
    type: 'dailyBeaten',
    title: `🏆 ${displayName(scorer.name)} עקף/ה אתכם באתגר היומי`,
    body: `${scorer.score} נקודות מול ${myScore} שלכם. מחר יש אתגר חדש - הזדמנות לנקום 😉`,
    route: '/daily',
    key: dailyBeatenKey(scorer.uid, dateKey),
    ttlSeconds: 12 * 3600,
  };
}

/**
 * הודעת FCM מוכנה לשליחה (בלי הטוקנים). השדות ב-data נקראים באפליקציה
 * ב-lib/core/notifications/push_message.dart.
 */
export function buildMessage(
  content: PushContent,
  options: { webAppUrl: string; nowMs: number },
): Omit<MulticastMessage, 'tokens'> {
  const { key } = content;
  const link = new URL(content.route, options.webAppUrl).toString();
  return {
    notification: { title: content.title, body: content.body },
    data: { type: content.type, route: content.route, tag: key.tag, nid: String(key.id) },
    android: {
      priority: 'high',
      ttl: content.ttlSeconds * 1000,
      notification: {
        // הערוץ נוצר באפליקציה (notification_service.dart). אותו tag כמו
        // בהתראה המקומית - ההתראות מחליפות זו את זו.
        channelId: 'social',
        tag: key.tag,
        icon: 'ic_stat_notify',
        color: '#7B3FF2',
        sound: 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': String(key.id),
        'apns-expiration': String(Math.floor(options.nowMs / 1000) + content.ttlSeconds),
      },
      payload: { aps: { sound: 'default', threadId: 'social' } },
    },
    webpush: {
      headers: { TTL: String(content.ttlSeconds), Urgency: 'high' },
      notification: { tag: key.tag, icon: '/icons/Icon-192.png', dir: 'rtl', lang: 'he' },
      fcmOptions: { link },
    },
  };
}
