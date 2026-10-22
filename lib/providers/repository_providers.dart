import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firebase_progress_repository.dart';
import '../data/repositories/local_progress_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/services/firebase_bootstrap.dart';
import 'auth_provider.dart';

/// ה-repository הפעיל להתקדמות השחקן.
///
/// כברירת מחדל (AppConfig.useFirebaseBackend == false) המשחק משתמש
/// ב-[LocalProgressRepository] (Hive) בלבד - עובד לגמרי אופליין. לאחר
/// הרצת `flutterfire configure` והפעלת הדגל (ראו docs/FIREBASE_SETUP.md),
/// המתג עובר אוטומטית ל-[FirebaseProgressRepository] מבלי לשנות שום
/// מסך במשחק.
///
/// ב-Firebase ה-repository קשור ל-uid המחובר: כל החלפת חשבון (התנתקות,
/// התחברות לחשבון קיים, מחיקה) יוצרת repository חדש, וכך גם הפרופיל
/// (playerProfileProvider) נטען מחדש לחשבון הנכון.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  if (isFirebaseBackendReady()) {
    final uid = ref.watch(authStateProvider.select((s) => s.valueOrNull?.uid));
    return FirebaseProgressRepository(boundUid: uid);
  }
  return LocalProgressRepository();
});
