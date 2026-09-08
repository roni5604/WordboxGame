import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/sound_service.dart';
import 'player_profile_provider.dart';

/// מופע יחיד (singleton) של שירות הצלילים לכל האפליקציה. נשאר קבוע לאורך
/// חיי האפליקציה כדי לא ליצור/להשמיד AudioPlayers שוב ושוב - רק דגל
/// ה-[SoundService.enabled] מתעדכן בזמן אמת לפי הגדרת "צלילים" בפרופיל.
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);

  // מאזינים לשינויים בפרופיל כדי לעדכן מיד את מצב ה-mute, כולל הערך
  // ההתחלתי (fireImmediately) כדי שלא יתנגן צליל לפני שהגדרת המשתמש/ת נטענה.
  ref.listen(
    playerProfileProvider,
    (previous, next) {
      service.enabled = next.valueOrNull?.soundOn ?? true;
    },
    fireImmediately: true,
  );

  return service;
});
