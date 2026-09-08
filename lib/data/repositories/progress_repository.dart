import '../models/player_profile.dart';

/// ממשק מופשט לשמירת/טעינת התקדמות השחקן.
///
/// כברירת מחדל האפליקציה משתמשת ב-[LocalProgressRepository] (Hive, עובד
/// גם לגמרי אופליין וללא חשבון). כאשר Firebase יוגדר (ראו
/// docs/FIREBASE_SETUP.md) ניתן להחליף למימוש שמסנכרן גם לענן, מבלי
/// לשנות שורת קוד אחת במסכים עצמם.
abstract class ProgressRepository {
  Future<PlayerProfile> loadProfile();
  Future<void> saveProfile(PlayerProfile profile);
}
