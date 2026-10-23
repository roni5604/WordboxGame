import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_service.dart';

/// מוזיקת התפריטים (assets/audio/music_loop.wav, ראו tool/generate_music.py) -
/// לופ פופ קצבי של 33 שניות, באותו סולם כמו כל האפקטים.
///
/// מתנגנת רק בין משחקים, וכשכל התנאים מתקיימים: המוזיקה מופעלת בהגדרות,
/// אף מסך משחק לא פתוח ([enterGame]/[leaveGame]), האפליקציה בחזית, לא מוצגת
/// פרסומת במסך מלא, ובאתר - אחרי נגיעה ראשונה (הדפדפן חוסם ניגון לפני
/// אינטראקציה של המשתמש/ת).
class MusicService {
  MusicService() : _silent = false;

  /// שירות שקט לחלוטין שלא יוצר נגן אודיו כלל - לבדיקות ולצילומי מסך.
  MusicService.silent() : _silent = true;

  final bool _silent;

  /// עוצמה נמוכה - המוזיקה ברקע, האפקטים בחזית.
  static const double volume = 0.16;

  AudioPlayer? _player;
  bool _enabled = true;
  bool _foreground = true;
  bool _adShowing = false;
  bool _unlocked = !kIsWeb;
  int _gameScreens = 0;
  bool _playing = false;

  /// הגדרת "מוזיקה" בפרופיל.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _sync();
  }

  /// האפליקציה בחזית (false כשהיא ברקע או שהמסך ננעל).
  set foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _sync();
  }

  /// פרסומת במסך מלא מוצגת - למודעה יש קול משלה.
  set adShowing(bool value) {
    if (_adShowing == value) return;
    _adShowing = value;
    _sync();
  }

  /// מסך משחק נפתח - בזמן המשחק עצמו אין מוזיקה (רק אפקטים). מונה ולא
  /// דגל, כי במעבר בין שלבים המסך החדש נפתח לפני שהישן נסגר.
  void enterGame() {
    _gameScreens++;
    _sync();
  }

  /// מסך משחק נסגר (חזרה לתפריט / מסך תוצאות) - המוזיקה חוזרת.
  void leaveGame() {
    if (_gameScreens > 0) _gameScreens--;
    _sync();
  }

  /// נקרא בכל לחיצה - באתר זו ההזדמנות הראשונה שמותר בה לנגן.
  void userInteracted() {
    if (_unlocked) return;
    _unlocked = true;
    _sync();
  }

  /// האם התנאים לניגון מתקיימים (גם בשירות השקט - לבדיקות).
  @visibleForTesting
  bool get shouldPlay => _enabled && _gameScreens == 0 && _foreground && !_adShowing && _unlocked;

  Future<void> _sync() async {
    if (_silent) return;
    final want = shouldPlay;
    if (want == _playing) return;
    _playing = want;
    try {
      if (want) {
        final player = _player;
        if (player == null) {
          await SoundService.ensureAudioContext();
          final p = _player = AudioPlayer();
          await p.setReleaseMode(ReleaseMode.loop);
          await p.setVolume(volume);
          // אם המצב השתנה בזמן ההכנה (למשל המוזיקה כובתה) - לא מתחילים.
          if (!_playing) return;
          await p.play(AssetSource('audio/music_loop.wav'));
        } else {
          await player.resume();
        }
      } else {
        await _player?.pause();
      }
    } catch (_) {
      // אודיו הוא תוספת, לא קריטי - מתעלמים משגיאות ניגון (למשל חסימת
      // autoplay בדפדפן, או סביבת בדיקות בלי ערוץ פלטפורמה).
    }
  }

  void dispose() {
    _player?.dispose();
  }
}
