import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/multiplayer/services/firestore_multiplayer_repository.dart';
import '../features/multiplayer/services/multiplayer_repository.dart';

/// ה-repository הפעיל למצב "משחק מול חברים" - עוקב אחרי אותה תבנית בדיוק
/// כמו [authRepositoryProvider]/[progressRepositoryProvider]: Firestore
/// אמיתי כשה-backend מופעל, אחרת stub שמסביר שהמצב דורש אינטרנט.
final multiplayerRepositoryProvider = Provider<MultiplayerRepository>((ref) {
  if (AppConfig.useFirebaseBackend) {
    return FirestoreMultiplayerRepository();
  }
  return UnimplementedMultiplayerRepository();
});
