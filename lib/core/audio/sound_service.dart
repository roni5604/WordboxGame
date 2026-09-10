import 'package:audioplayers/audioplayers.dart';

/// שירות צלילים פשוט - מנגן אפקטים קצרים (SFX) לאירועי משחק מרכזיים.
/// שומר "בריכה" קטנה של נגנים כדי שכמה צלילים יוכלו להתנגן זה על זה
/// בלי לחתוך אחד את השני (למשל שני "פינג" של מציאת מילה ברצף מהיר).
///
/// כל הקבצים ב-assets/audio נוצרו פרוצדורלית (ראו tool/generate_sfx.py) -
/// טונים סינתטיים פשוטים, בלי תלות בקבצי אודיו חיצוניים או סוגיות רישוי.
class SoundService {
  SoundService() : _pool = List.generate(4, (_) => AudioPlayer()) {
    for (final p in _pool) {
      // fire-and-forget עם catchError: בסביבת בדיקות (widget tests) אין
      // ערוץ פלטפורמה אמיתי לאודיו, וזה לא אמור להפיל שום טסט.
      p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
      p.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    }
  }

  final List<AudioPlayer> _pool;
  int _next = 0;

  /// כאשר false (השחקן/ית כיבו צלילים בהגדרות), כל קריאה הופכת ל-no-op.
  bool enabled = true;

  Future<void> _play(String file, {double volume = 0.8}) async {
    if (!enabled) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/$file'));
    } catch (_) {
      // מתעלמים משגיאות ניגון (למשל חסימת autoplay בדפדפן לפני אינטראקציה
      // ראשונה של המשתמש/ת) - אודיו הוא תוספת, לא קריטי לגיימפליי.
    }
  }

  /// מילה תקינה נמצאה - ארפג'יו שמח וקצר.
  Future<void> playSuccess() => _play('success_word.wav');

  /// ניסיון מילה לא תקין/כפול - צליל שלילי קצר, לא מציק.
  Future<void> playError() => _play('error_word.wav', volume: 0.6);

  /// נגיעה ראשונה באות בתחילת גרירה.
  Future<void> playTileTap() => _play('tile_tap.wav', volume: 0.5);

  /// סיום שלב בהצלחה - פנפרה קטנה.
  Future<void> playLevelComplete() => _play('level_complete.wav');

  /// שימוש ברמז - נצנוץ קסום.
  Future<void> playHint() => _play('hint.wav');

  /// קבלת/הוצאת מטבעות.
  Future<void> playCoin() => _play('coin.wav');

  /// בונוס יומי.
  Future<void> playDailyReward() => _play('daily_reward.wav');

  /// קליק UI כללי לכפתורים ראשיים.
  Future<void> playButtonTap() => _play('button_tap.wav', volume: 0.4);

  /// אזהרת זמן אוזל (מספר שניות אחרונות בטיימר).
  Future<void> playTimerWarning() => _play('timer_warning.wav', volume: 0.5);

  /// כוכב הושג במהלך השלב (חגיגת-ביניים, בנוסף לחגיגה הגדולה בסיום).
  Future<void> playStarGained() => _play('star_gained.wav', volume: 0.7);

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
  }
}
