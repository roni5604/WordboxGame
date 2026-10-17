// בדיקות לחוקי האבטחה של Firestore (firestore.rules) מול האמולטור.
// מריצים: npm ci && npx firebase emulators:exec --only firestore --project demo-wordbox "npm test"
//
// כל בדיקה "מותרת" משחזרת כתיבה שהאפליקציה באמת עושה (כדי לוודא שהחוקים
// לא שוברים את המשחק), וכל בדיקה "חסומה" משחזרת ניסיון תקיפה.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  documentId,
  getDoc,
  getDocs,
  increment,
  limit,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wordbox',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

const GOOGLE_PHOTO = 'https://lh3.googleusercontent.com/a/abc=s96-c';

function profile(name) {
  return {
    displayName: name,
    displayNameLower: name.toLowerCase(),
    avatarId: 'detective',
    photoUrl: null,
    friendCode: 'ABC234',
    totalStars: 12,
    highestLevel: 5,
    updatedAt: serverTimestamp(),
  };
}

function room(hostUid, overrides = {}) {
  return {
    status: 'waiting',
    hostUid,
    gridSize: 4,
    boardSeed: 123,
    roundSeconds: 90,
    targetScore: 0,
    maxPlayers: 4,
    totalRounds: 1,
    currentRound: 1,
    entryFee: 5,
    pot: 5,
    paidUids: { [hostUid]: true },
    potAwarded: false,
    joinDeadline: Timestamp.fromDate(new Date(Date.now() + 600000)),
    startedAt: null,
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function roomPlayer(name, isHost) {
  return {
    displayName: name,
    score: 0,
    wordsFound: 0,
    isHost,
    avatarId: 'detective',
    photoUrl: null,
    joinedAt: serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
describe('players (התקדמות פרטית)', () => {
  test('שחקן/ית שומר/ת התקדמות', async () => {
    await assertSucceeds(
      setDoc(doc(db('alice'), 'players/alice'), {
        coins: 120,
        hints: 5,
        highestUnlockedLevel: 3,
        displayName: 'אליס',
        levelProgress: { 1: { stars: 3, bestScore: 40, completed: true } },
        updatedAt: serverTimestamp(),
      }, { merge: true }),
    );
  });

  test('פרופיל מלא כמו ש-saveProfile כותב (משתמש/ת חדש/ה, ואז קריאה)', async () => {
    const me = db('guest1');
    await assertSucceeds(getDoc(doc(me, 'players/guest1')));
    const full = {
      levelProgress: {},
      coins: 0,
      highestUnlockedLevel: 1,
      soundOn: true,
      hapticsOn: true,
      onboardingCompleted: false,
      displayName: 'שחקן/ית',
      avatarId: 'detective',
      hints: 5,
      hintStreakDay: 0,
      lastHintClaimDate: null,
      authIntroShown: false,
      level1TutorialSeen: false,
      doubleCoinsLevelsRemaining: 0,
      boardSkinId: 'classic',
      letterSkinId: 'classic',
      markerSkinId: 'classic',
      ownedBoardSkins: ['classic'],
      ownedLetterSkins: ['classic'],
      ownedMarkerSkins: ['classic'],
      dailyChallengeDate: null,
      dailyChallengeScore: 0,
      dailyChallengeWords: 0,
      dailyChallengeStreak: 0,
      dailyChallengeBestStreak: 0,
      dailyChallengeStartedDate: null,
      dropsSinceEpic: 0,
      updatedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(me, 'players/guest1'), full, { merge: true }));
    await assertSucceeds(getDoc(doc(me, 'players/guest1')));
    await assertSucceeds(setDoc(doc(me, 'players/guest1'), { ...full, coins: 40, levelProgress: { 1: { stars: 3, bestScore: 40, completed: true } } }, { merge: true }));
  });

  test('אי אפשר לקרוא או לכתוב התקדמות של מישהו אחר', async () => {
    await seed((f) => setDoc(doc(f, 'players/alice'), { coins: 1 }));
    await assertFails(getDoc(doc(db('bob'), 'players/alice')));
    await assertFails(setDoc(doc(db('bob'), 'players/alice'), { coins: 999 }));
    await assertFails(getDoc(doc(anon(), 'players/alice')));
  });

  test('ערכים לא הגיוניים נחסמים', async () => {
    await assertFails(setDoc(doc(db('alice'), 'players/alice'), { coins: -5 }));
    await assertFails(setDoc(doc(db('alice'), 'players/alice'), { coins: 'lots' }));
    await assertFails(setDoc(doc(db('alice'), 'players/alice'), { hints: 1e9 }));
  });

  test('מחיקת חשבון: מוחקים את המסמך שלי', async () => {
    await seed((f) => setDoc(doc(f, 'players/alice'), { coins: 1 }));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'players/alice')));
  });
});

// ---------------------------------------------------------------------------
describe('publicProfiles (כרטיס ציבורי)', () => {
  test('פרסום כרטיס ודופק נוכחות', async () => {
    const me = db('alice');
    await assertSucceeds(setDoc(doc(me, 'publicProfiles/alice'), profile('אליס'), { merge: true }));
    await assertSucceeds(
      setDoc(doc(me, 'publicProfiles/alice'), {
        status: 'online',
        lastActive: serverTimestamp(),
        friendCode: 'ABC234',
      }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(doc(me, 'publicProfiles/alice'), { mpGames: increment(1), mpWins: increment(1) }, { merge: true }),
    );
  });

  test('תמונת פרופיל מ-Google מותרת, מכתובת שרירותית לא', async () => {
    const me = db('alice');
    await assertSucceeds(setDoc(doc(me, 'publicProfiles/alice'), { ...profile('a'), photoUrl: GOOGLE_PHOTO }));
    await assertFails(setDoc(doc(me, 'publicProfiles/alice'), { ...profile('a'), photoUrl: 'https://evil.example/track.gif' }));
    await assertFails(setDoc(doc(me, 'publicProfiles/alice'), { ...profile('a'), photoUrl: 'http://lh3.googleusercontent.com/x' }));
    await assertFails(
      setDoc(doc(me, 'publicProfiles/alice'), { ...profile('a'), photoUrl: 'https://googleusercontent.com.evil.example/x' }),
    );
  });

  test('שם ארוך מדי וסטטוס לא חוקי נחסמים', async () => {
    const me = db('alice');
    await assertFails(setDoc(doc(me, 'publicProfiles/alice'), profile('x'.repeat(41))));
    await assertFails(setDoc(doc(me, 'publicProfiles/alice'), { ...profile('a'), status: 'admin' }));
  });

  test('אי אפשר לכתוב כרטיס של מישהו אחר', async () => {
    await assertFails(setDoc(doc(db('bob'), 'publicProfiles/alice'), profile('מתחזה')));
  });

  test('חיפוש לפי קוד חבר וטעינת כרטיסים - רק עם limit', async () => {
    await seed((f) => setDoc(doc(f, 'publicProfiles/alice'), profile('אליס')));
    const bob = db('bob');
    await assertSucceeds(getDoc(doc(bob, 'publicProfiles/alice')));
    await assertSucceeds(getDocs(query(collection(bob, 'publicProfiles'), where('friendCode', '==', 'ABC234'), limit(10))));
    await assertSucceeds(getDocs(query(collection(bob, 'publicProfiles'), where(documentId(), 'in', ['alice']), limit(1))));
    await assertFails(getDocs(collection(bob, 'publicProfiles')));
    await assertFails(getDocs(query(collection(bob, 'publicProfiles'), limit(500))));
    await assertFails(getDoc(doc(anon(), 'publicProfiles/alice')));
  });
});

// ---------------------------------------------------------------------------
describe('חברים ובקשות חברות', () => {
  async function seedProfiles() {
    await seed(async (f) => {
      await setDoc(doc(f, 'publicProfiles/alice'), profile('אליס'));
      await setDoc(doc(f, 'publicProfiles/bob'), profile('בוב'));
    });
  }

  function request(from, to) {
    return {
      from,
      to,
      fromName: from,
      fromAvatarId: 'detective',
      fromPhotoUrl: null,
      toName: to,
      createdAt: serverTimestamp(),
    };
  }

  test('בקשה, אישור, ותיעוד משחק', async () => {
    await seedProfiles();
    await assertSucceeds(setDoc(doc(db('alice'), 'friendRequests/alice_bob'), request('alice', 'bob')));

    const bob = db('bob');
    const batch = writeBatch(bob);
    const entry = { since: serverTimestamp(), wins: 0, losses: 0, games: 0 };
    batch.set(doc(bob, 'publicProfiles/bob/friends/alice'), entry, { merge: true });
    batch.set(doc(bob, 'publicProfiles/alice/friends/bob'), entry, { merge: true });
    batch.delete(doc(bob, 'friendRequests/alice_bob'));
    await assertSucceeds(batch.commit());

    await assertSucceeds(
      setDoc(doc(db('alice'), 'publicProfiles/alice/friends/bob'), {
        games: increment(1),
        wins: increment(1),
        lastPlayed: serverTimestamp(),
      }, { merge: true }),
    );
  });

  test('אי אפשר להוסיף מישהו לחברים בלי בקשה', async () => {
    await seedProfiles();
    await assertFails(
      setDoc(doc(db('alice'), 'publicProfiles/alice/friends/bob'), { since: serverTimestamp(), wins: 0, losses: 0, games: 0 }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'publicProfiles/bob/friends/alice'), { since: serverTimestamp(), wins: 0, losses: 0, games: 0 }),
    );
  });

  test('בקשה מזויפת נחסמת', async () => {
    await seedProfiles();
    // בשם מישהו אחר
    await assertFails(setDoc(doc(db('eve'), 'friendRequests/alice_bob'), request('alice', 'bob')));
    // תמונה מכתובת זרה
    await assertFails(
      setDoc(doc(db('alice'), 'friendRequests/alice_bob'), { ...request('alice', 'bob'), fromPhotoUrl: 'https://evil.example/x.png' }),
    );
    // שדות נוספים
    await assertFails(setDoc(doc(db('alice'), 'friendRequests/alice_bob'), { ...request('alice', 'bob'), admin: true }));
    // למשתמש שלא קיים
    await assertFails(setDoc(doc(db('alice'), 'friendRequests/alice_ghost'), request('alice', 'ghost')));
  });

  test('רק הצדדים לבקשה יכולים לקרוא אותה', async () => {
    await seed((f) => setDoc(doc(f, 'friendRequests/alice_bob'), { from: 'alice', to: 'bob' }));
    await assertSucceeds(getDoc(doc(db('bob'), 'friendRequests/alice_bob')));
    await assertFails(getDoc(doc(db('eve'), 'friendRequests/alice_bob')));
  });

  test('מחיקת חשבון: מוחקים את הרשומה שלי אצל חבר/ה', async () => {
    await seed(async (f) => {
      await setDoc(doc(f, 'publicProfiles/bob/friends/alice'), { wins: 0 });
      await setDoc(doc(f, 'publicProfiles/alice'), profile('אליס'));
    });
    await assertSucceeds(deleteDoc(doc(db('alice'), 'publicProfiles/bob/friends/alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'publicProfiles/alice')));
  });
});

// ---------------------------------------------------------------------------
describe('חדרי משחק', () => {
  async function seedRoom(overrides = {}) {
    await seed(async (f) => {
      await setDoc(doc(f, 'rooms/12345'), room('host', overrides));
      await setDoc(doc(f, 'rooms/12345/players/host'), roomPlayer('מנהל', true));
    });
  }

  test('יצירת חדר כמו באפליקציה', async () => {
    const host = db('host');
    await assertSucceeds(setDoc(doc(host, 'rooms/54321'), room('host')));
    await assertSucceeds(setDoc(doc(host, 'rooms/54321/players/host'), roomPlayer('מנהל', true)));
  });

  test('יצירת חדר לא חוקי נחסמת', async () => {
    const host = db('host');
    await assertFails(setDoc(doc(host, 'rooms/54321'), room('someone-else')));
    await assertFails(setDoc(doc(host, 'rooms/abcde'), room('host')));
    await assertFails(setDoc(doc(host, 'rooms/54321'), room('host', { paidUids: { host: true, bob: true } })));
    await assertFails(setDoc(doc(host, 'rooms/54321'), room('host', { gridSize: 50 })));
    await assertFails(setDoc(doc(host, 'rooms/54321'), room('host', { extra: 'x' })));
  });

  test('הצטרפות כמו באפליקציה (טרנזקציה: שחקן + קופה)', async () => {
    await seedRoom();
    const guest = db('guest');
    const batch = writeBatch(guest);
    batch.set(doc(guest, 'rooms/12345/players/guest'), roomPlayer('אורח', false));
    batch.update(doc(guest, 'rooms/12345'), { paidUids: { host: true, guest: true }, pot: 10 });
    await assertSucceeds(batch.commit());
  });

  test('הצטרפות במרמה נחסמת', async () => {
    await seedRoom();
    const guest = db('guest');
    // ניקוד התחלתי
    await assertFails(setDoc(doc(guest, 'rooms/12345/players/guest'), { ...roomPlayer('אורח', false), score: 500 }));
    // להתחזות למנהל
    await assertFails(setDoc(doc(guest, 'rooms/12345/players/guest'), roomPlayer('אורח', true)));
    // בשם מישהו אחר
    await assertFails(setDoc(doc(guest, 'rooms/12345/players/bob'), roomPlayer('בוב', false)));
    // לשנות את המנהל בזמן ההצטרפות
    await assertFails(updateDoc(doc(guest, 'rooms/12345'), { paidUids: { host: true, guest: true }, pot: 10, hostUid: 'guest' }));
    // להסיר מישהו אחר מהקופה
    await assertFails(updateDoc(doc(guest, 'rooms/12345'), { paidUids: { guest: true }, pot: 10 }));
  });

  test('אי אפשר להצטרף לחדר שהמשחק בו כבר התחיל', async () => {
    await seedRoom({ status: 'inProgress' });
    await assertFails(setDoc(doc(db('guest'), 'rooms/12345/players/guest'), roomPlayer('אורח', false)));
  });

  test('אין רשימה של כל החדרים, אבל אפשר לפתוח חדר לפי קוד', async () => {
    await seedRoom();
    await assertFails(getDocs(collection(db('eve'), 'rooms')));
    await assertSucceeds(getDoc(doc(db('eve'), 'rooms/12345')));
    await assertSucceeds(getDocs(collection(db('eve'), 'rooms/12345/players')));
  });

  test('מהלך משחק מלא: התחלה, ניקוד, סיום, משחק חוזר וסבב הבא', async () => {
    await seedRoom({ totalRounds: 3 });
    await seed((f) => setDoc(doc(f, 'rooms/12345/players/guest'), roomPlayer('אורח', false)));
    const host = db('host');
    const guest = db('guest');

    await assertSucceeds(updateDoc(doc(host, 'rooms/12345'), { status: 'inProgress', startedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(guest, 'rooms/12345/players/guest'), { score: 12, wordsFound: 3 }));
    await assertSucceeds(
      updateDoc(doc(guest, 'rooms/12345'), { status: 'finished', wins: { guest: 1 } }),
    );

    const next = writeBatch(host);
    next.update(doc(host, 'rooms/12345'), {
      status: 'inProgress',
      boardSeed: 999,
      startedAt: serverTimestamp(),
      currentRound: 2,
    });
    next.update(doc(host, 'rooms/12345/players/guest'), { score: 0, wordsFound: 0 });
    next.update(doc(host, 'rooms/12345/players/host'), { score: 0, wordsFound: 0 });
    await assertSucceeds(next.commit());

    await assertSucceeds(updateDoc(doc(guest, 'rooms/12345'), { status: 'finished', wins: { guest: 2 } }));
    const restart = writeBatch(host);
    restart.update(doc(host, 'rooms/12345'), { status: 'waiting', boardSeed: 5, startedAt: null });
    restart.update(doc(host, 'rooms/12345/players/guest'), { score: 0, wordsFound: 0 });
    await assertSucceeds(restart.commit());
  });

  test('רמאות בניקוד נחסמת', async () => {
    await seedRoom({ status: 'inProgress' });
    await seed((f) => setDoc(doc(f, 'rooms/12345/players/guest'), { ...roomPlayer('אורח', false), score: 20, wordsFound: 4 }));
    const guest = db('guest');
    await assertFails(updateDoc(doc(guest, 'rooms/12345/players/guest'), { score: 5, wordsFound: 4 }));
    await assertFails(updateDoc(doc(guest, 'rooms/12345/players/guest'), { score: 99999999, wordsFound: 4 }));
    await assertFails(updateDoc(doc(guest, 'rooms/12345/players/guest'), { score: 30, wordsFound: 5, isHost: true }));
    await assertFails(updateDoc(doc(guest, 'rooms/12345/players/host'), { score: 0, wordsFound: 0 }));
    // מי שלא בחדר לא יכול לסיים אותו
    await assertFails(updateDoc(doc(db('eve'), 'rooms/12345'), { status: 'finished' }));
  });

  test('יציאה מהלובי מחזירה את דמי הכניסה מהקופה', async () => {
    await seedRoom({ paidUids: { host: true, guest: true }, pot: 10 });
    await seed((f) => setDoc(doc(f, 'rooms/12345/players/guest'), roomPlayer('אורח', false)));
    const guest = db('guest');
    const batch = writeBatch(guest);
    batch.delete(doc(guest, 'rooms/12345/players/guest'));
    batch.update(doc(guest, 'rooms/12345'), { 'paidUids.guest': deleteField(), pot: 5 });
    await assertSucceeds(batch.commit());
  });
});

// ---------------------------------------------------------------------------
describe('הזמנות למשחק', () => {
  function invite(from, to, roomCode = '12345') {
    return {
      from,
      to,
      fromName: from,
      fromAvatarId: 'detective',
      fromPhotoUrl: null,
      toName: to,
      roomCode,
      gridSize: 4,
      roundSeconds: 90,
      entryFee: 5,
      status: 'pending',
      createdAt: serverTimestamp(),
    };
  }

  test('מנהל/ת החדר מזמינ/ה, והנמען/ת עונה', async () => {
    await seed(async (f) => {
      await setDoc(doc(f, 'rooms/12345'), room('host'));
      await setDoc(doc(f, 'rooms/12345/players/host'), roomPlayer('מנהל', true));
    });
    await assertSucceeds(setDoc(doc(db('host'), 'invites/i1'), invite('host', 'bob')));
    await assertSucceeds(
      updateDoc(doc(db('bob'), 'invites/i1'), { status: 'accepted', respondedAt: serverTimestamp() }),
    );
  });

  test('הזמנה לחדר שאני לא בו, או עם שדות זרים, נחסמת', async () => {
    await seed((f) => setDoc(doc(f, 'rooms/12345'), room('host')));
    await assertFails(setDoc(doc(db('eve'), 'invites/i1'), invite('eve', 'bob')));
    await assertFails(setDoc(doc(db('host'), 'invites/i2'), { ...invite('host', 'bob'), roomCode: '12345/players/x' }));
    await assertFails(setDoc(doc(db('host'), 'invites/i3'), invite('bob', 'alice')));
  });

  test('הנמען/ת לא יכול/ה לשנות פרטים אחרים בהזמנה', async () => {
    await seed((f) => setDoc(doc(f, 'invites/i1'), invite('host', 'bob')));
    await assertFails(updateDoc(doc(db('bob'), 'invites/i1'), { status: 'accepted', entryFee: 0 }));
    await assertFails(getDoc(doc(db('eve'), 'invites/i1')));
  });
});
