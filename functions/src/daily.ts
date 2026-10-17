// "חבר/ה עקף/ה אותך באתגר היומי" - מתי לשלוח ולמי. לוגיקה טהורה.
//
// הכרטיס הציבורי (publicProfiles/{uid}) מתעדכן כל דקה (דופק נוכחות), אז
// הבדיקה הראשונה ([scoreRaise]) זולה ולא קוראת כלום מ-Firestore.

export interface DailyFields {
  dailyDate?: unknown;
  dailyScore?: unknown;
}

export interface ScoreRaise {
  dateKey: string;
  previous: number;
  current: number;
}

const DATE_KEY = /^\d{4}-\d{2}-\d{2}$/;

function score(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : 0;
}

/** הניקוד היומי עלה בעדכון הזה? (יום חדש = התחלה מאפס.) */
export function scoreRaise(before: DailyFields | undefined, after: DailyFields | undefined): ScoreRaise | null {
  const dateKey = after?.dailyDate;
  if (typeof dateKey !== 'string' || !DATE_KEY.test(dateKey)) return null;
  const current = score(after?.dailyScore);
  const previous = before?.dailyDate === dateKey ? score(before?.dailyScore) : 0;
  if (current <= previous) return null;
  return { dateKey, previous, current };
}

export interface FriendDaily extends DailyFields {
  uid: string;
}

/**
 * חברים ששיחקו היום ושהניקוד הזה עקף אותם עכשיו: לפני העדכון הם היו
 * מעליי (או בתיקו), ואחריו אני מעליהם. ככה כל חבר/ה מקבל/ת התראה אחת לכל
 * היותר על אותה עקיפה.
 */
export function beatenFriends(raise: ScoreRaise, friends: FriendDaily[]): FriendDaily[] {
  return friends.filter((friend) => {
    if (friend.dailyDate !== raise.dateKey) return false;
    const theirs = score(friend.dailyScore);
    return theirs > 0 && theirs >= raise.previous && theirs < raise.current;
  });
}
