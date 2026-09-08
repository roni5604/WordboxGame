import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/auth_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/local_auth_repository.dart';

/// ה-repository הפעיל להתחברות - עוקב אחרי אותה תבנית בדיוק כמו
/// [progressRepositoryProvider]: אורח בלבד כברירת מחדל, Firebase אמיתי
/// לאחר הפעלת AppConfig.useFirebaseBackend.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useFirebaseBackend) {
    return FirebaseAuthRepository();
  }
  return LocalAuthRepository();
});

/// זרם המשתמש המחובר הנוכחי - null עד לאתחול הראשוני. משמש את מסך
/// הפרופיל ואת מסך ההתחברות כדי להציג את המצב העדכני בזמן אמת.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
