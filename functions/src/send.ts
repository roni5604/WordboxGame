// שליחה לכל המכשירים של שחקן/ית (players/{uid}/devices/{token}) וניקוי
// טוקנים ש-FCM כבר לא מכיר.
import type { Firestore } from 'firebase-admin/firestore';
import type { BatchResponse, MulticastMessage } from 'firebase-admin/messaging';

/** שגיאות שאומרות שהטוקן עצמו מת - רק אז מוחקים אותו. */
const DEAD_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// שימו לב: 'messaging/third-party-auth-error' (למשל כשעוד לא הועלה מפתח
// APNs לקונסולה) הוא לא טוקן מת - לא מוחקים, אחרת כל מכשירי ה-iOS ייעלמו.

const MAX_TOKENS_PER_CALL = 500;

export interface DeviceStore {
  tokens(uid: string): Promise<string[]>;
  remove(uid: string, tokens: string[]): Promise<void>;
}

export interface Sender {
  sendEachForMulticast(message: MulticastMessage): Promise<BatchResponse>;
}

export interface SendResult {
  sent: number;
  failed: number;
  removed: number;
  /** קודי השגיאה מ-FCM (בלי כפילויות) - ללוג. */
  errors: string[];
}

export async function sendToUser(
  store: DeviceStore,
  sender: Sender,
  uid: string,
  message: Omit<MulticastMessage, 'tokens'>,
): Promise<SendResult> {
  const result: SendResult = { sent: 0, failed: 0, removed: 0, errors: [] };
  const tokens = await store.tokens(uid);
  for (let i = 0; i < tokens.length; i += MAX_TOKENS_PER_CALL) {
    const chunk = tokens.slice(i, i + MAX_TOKENS_PER_CALL);
    const response = await sender.sendEachForMulticast({ ...message, tokens: chunk });
    const dead: string[] = [];
    response.responses.forEach((r, index) => {
      if (r.success) {
        result.sent++;
        return;
      }
      result.failed++;
      const code = r.error?.code ?? 'unknown';
      if (!result.errors.includes(code)) result.errors.push(code);
      if (DEAD_TOKEN_ERRORS.has(code)) dead.push(chunk[index]);
    });
    if (dead.length) {
      await store.remove(uid, dead);
      result.removed += dead.length;
    }
  }
  return result;
}

export function firestoreDeviceStore(db: Firestore): DeviceStore {
  const devices = (uid: string) => db.collection('players').doc(uid).collection('devices');
  return {
    async tokens(uid) {
      const snap = await devices(uid).select().get();
      return snap.docs.map((d) => d.id);
    },
    async remove(uid, tokens) {
      const batch = db.batch();
      for (const token of tokens) batch.delete(devices(uid).doc(token));
      await batch.commit();
    },
  };
}
