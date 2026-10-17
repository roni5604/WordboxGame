// מזהה יציב לכל התראה חברתית - העתק מדויק של
// lib/core/notifications/social_notification_keys.dart באפליקציה.
//
// אותו אירוע מקבל אותו id ואותו tag גם ב-push מהשרת וגם בהתראה המקומית
// שהאפליקציה מציגה כשהיא ברקע, ולכן מערכת ההפעלה מחליפה אחת בשנייה במקום
// להציג פעמיים (Android: tag, iOS: apns-collapse-id = id, אתר: tag).

export interface NotificationKey {
  id: number;
  tag: string;
}

export const INVITE_BASE = 2000;
export const FRIEND_REQUEST_BASE = 3000;
export const DAILY_BEATEN_BASE = 4000;

/** FNV-1a של 32 ביט על בייטים של UTF-8. */
export function stableHash(input: string): number {
  let hash = 0x811c9dc5;
  for (const byte of Buffer.from(input, 'utf8')) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

export function inviteKey(inviteId: string): NotificationKey {
  return { id: INVITE_BASE + (stableHash(`invite:${inviteId}`) % 1000), tag: `invite-${inviteId}` };
}

export function friendRequestKey(requestId: string): NotificationKey {
  return { id: FRIEND_REQUEST_BASE + (stableHash(`friend:${requestId}`) % 1000), tag: `friend-${requestId}` };
}

export function dailyBeatenKey(friendUid: string, dateKey: string): NotificationKey {
  return {
    id: DAILY_BEATEN_BASE + (stableHash(`daily:${friendUid}:${dateKey}`) % 1000),
    tag: `daily-${friendUid}-${dateKey}`,
  };
}
