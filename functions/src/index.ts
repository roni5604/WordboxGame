// פונקציות ענן של "מצא ת׳מילה": push שמגיע גם כשהאפליקציה סגורה.
//
//   onInviteCreated        invites/{id}              → לנמען/ת
//   onFriendRequestCreated friendRequests/{id}       → לנמען/ת
//   onDailyScoreRaised     publicProfiles/{uid}      → לחברים שעקפתי היום
//   onDeviceRegistered     players/{uid}/devices/{t} → אותו מכשיר לא נשאר רשום אצל חשבון קודם
//
// המכשירים נרשמים מהאפליקציה (lib/core/notifications/push_service.dart).
// הפריסה דורשת תוכנית Blaze - ראו docs/PUSH_NOTIFICATIONS.md.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as logger from 'firebase-functions/logger';
import { defineString } from 'firebase-functions/params';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { beatenFriends, scoreRaise, type FriendDaily } from './daily.js';
import { buildMessage, dailyBeatenContent, friendRequestContent, inviteContent, type PushContent } from './messages.js';
import { firestoreDeviceStore, sendToUser } from './send.js';

initializeApp();

// באותו אזור כמו מסד הנתונים (Firestore ב-europe-west1).
setGlobalOptions({ region: 'europe-west1', maxInstances: 10, memory: '256MiB' });

/** כתובת האתר, ללחיצה על התראה בדפדפן. */
const WEB_APP_URL = defineString('WEB_APP_URL', { default: 'https://wordbox-64b19.web.app' });

const db = () => getFirestore();

async function push(uid: string, content: PushContent): Promise<void> {
  const message = buildMessage(content, { webAppUrl: WEB_APP_URL.value(), nowMs: Date.now() });
  const result = await sendToUser(firestoreDeviceStore(db()), getMessaging(), uid, message);
  logger.info('push', { type: content.type, to: uid, ...result });
}

export const onInviteCreated = onDocumentCreated('invites/{inviteId}', async (event) => {
  const invite = event.data?.data();
  if (!invite) return;
  const content = inviteContent(event.params.inviteId, invite);
  if (content) await push(invite.to as string, content);
});

export const onFriendRequestCreated = onDocumentCreated('friendRequests/{requestId}', async (event) => {
  const request = event.data?.data();
  if (!request) return;
  const content = friendRequestContent(event.params.requestId, request);
  if (content) await push(request.to as string, content);
});

export const onDailyScoreRaised = onDocumentUpdated('publicProfiles/{uid}', async (event) => {
  // רוב העדכונים כאן הם דופק נוכחות - יוצאים בלי לקרוא כלום.
  const after = event.data?.after.data();
  const raise = scoreRaise(event.data?.before.data(), after);
  if (!raise || !after) return;

  const uid = event.params.uid;
  const friendIds = (await db().collection('publicProfiles').doc(uid).collection('friends').select().get()).docs.map(
    (d) => d.id,
  );
  if (!friendIds.length) return;

  const refs = friendIds.map((id) => db().collection('publicProfiles').doc(id));
  const friends: FriendDaily[] = [];
  for (let i = 0; i < refs.length; i += 100) {
    const snaps = await db().getAll(...refs.slice(i, i + 100), { fieldMask: ['dailyDate', 'dailyScore'] });
    for (const snap of snaps) {
      if (snap.exists) friends.push({ uid: snap.id, ...snap.data() });
    }
  }

  const scorer = { uid, name: after.displayName, score: raise.current };
  await Promise.all(
    beatenFriends(raise, friends).map((friend) =>
      push(friend.uid, dailyBeatenContent(scorer, Number(friend.dailyScore), raise.dateKey)),
    ),
  );
});

// אותו טוקן נרשם עכשיו לחשבון הזה - אם הוא עדיין רשום אצל חשבון אחר
// (התנתקות בלי רשת, החלפת משתמש/ת), מוחקים שם, כדי שהתראות של חשבון אחד
// לא יגיעו למכשיר של חשבון אחר.
export const onDeviceRegistered = onDocumentCreated('players/{uid}/devices/{token}', async (event) => {
  const { uid, token } = event.params;
  const same = await db().collectionGroup('devices').where('token', '==', token).get();
  const stale = same.docs.filter((d) => d.ref.parent.parent?.id !== uid);
  if (!stale.length) return;
  const batch = db().batch();
  for (const doc of stale) batch.delete(doc.ref);
  await batch.commit();
  logger.info('removed device from previous accounts', { uid, count: stale.length });
});
