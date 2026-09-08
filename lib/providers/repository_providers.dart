import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/repositories/firebase_progress_repository.dart';
import '../data/repositories/local_progress_repository.dart';
import '../data/repositories/progress_repository.dart';

/// ה-repository הפעיל להתקדמות השחקן.
///
/// כברירת מחדל (AppConfig.useFirebaseBackend == false) המשחק משתמש
/// ב-[LocalProgressRepository] (Hive) בלבד - עובד לגמרי אופליין. לאחר
/// הרצת `flutterfire configure` והפעלת הדגל (ראו docs/FIREBASE_SETUP.md),
/// המתג עובר אוטומטית ל-[FirebaseProgressRepository] מבלי לשנות שום
/// מסך במשחק.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  if (AppConfig.useFirebaseBackend) {
    return FirebaseProgressRepository();
  }
  return LocalProgressRepository();
});
