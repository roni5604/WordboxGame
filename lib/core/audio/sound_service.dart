import 'package:audioplayers/audioplayers.dart';

/// שירות צלילים פשוט - מנגן אפקטים קצרים (SFX) לאירועי משחק מרכזיים.
/// שומר "בריכה" קטנה של נגנים כדי שכמה צלילים יוכלו להתנגן זה על זה
/// בלי לחתוך אחד את השני (למשל שני "פינג" של מציאת מילה ברצף מהיר).
///
/// כל הקבצים ב-assets/audio נוצרו פרוצדורלית (ראו tool/generate_sfx.py) -
/// בועות, קלימבה, מרימבה ו"פשששש", בלי קבצי אודיו חיצוניים או סוגיות רישוי.
/// כולם באותו סולם, כך שצלילים שמתנגנים יחד נשמעים הרמוניים.
class SoundService {
  SoundService() : _silent = false;

  /// שירות שקט לחלוטין שלא יוצר נגני אודיו כלל - לבדיקות ולצילומי מסך.
  SoundService.silent() : _silent = true {
    enabled = false;
  }

  final bool _silent;

  /// נגני האודיו נוצרים רק בצליל הראשון (ולא בעליית האפליקציה) - חוסך
  /// עבודה בפריים הראשון.
  List<AudioPlayer>? _poolStorage;
  List<AudioPlayer> get _pool => _poolStorage ??= _createPool();

  List<AudioPlayer> _createPool() {
    ensureAudioContext();
    return List.generate(6, (_) {
    final p = AudioPlayer();
    // fire-and-forget עם catchError: בסביבת בדיקות (widget tests) אין
    // ערוץ פלטפורמה אמיתי לאודיו, וזה לא אמור להפיל שום טסט.
    p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
    p.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    return p;
    });
  }

  int _next = 0;

  static Future<void>? _audioContext;

  /// הגדרת אודיו משותפת לכל הנגנים (אפקטים ומוזיקה), פעם אחת: הצלילים
  /// שלנו מתערבבים עם מוזיקה שמתנגנת מאפליקציה אחרת ולא עוצרים אותה
  /// (iOS: mixWithOthers, Android: בלי audio focus).
  static Future<void> ensureAudioContext() => _audioContext ??= AudioPlayer.global
      .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
      .catchError((_) {});

  /// כאשר false (השחקן/ית כיבו צלילים בהגדרות), כל קריאה הופכת ל-no-op.
  bool enabled = true;

  Future<void> _play(String file, {double volume = 0.8}) async {
    if (!enabled || _silent) return;
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

  /// רצף מילים: כל מילה שנמצאת תוך [_comboWindow] מהקודמת (בלי שגיאה
  /// באמצע) מתחילה טון גבוה יותר - תחושת "התלהטות" כמו בקנדי קראש.
  static const _comboWindow = Duration(seconds: 8);
  int _combo = 0;
  DateTime? _lastWordAt;

  /// מילה תקינה נמצאה. [letters] = אורך המילה: 5 אותיות ומעלה מקבלות
  /// חגיגה גדולה יותר ("פששש" עם נצנצים ו"וואו").
  Future<void> playSuccess({int letters = 0}) {
    final now = DateTime.now();
    final last = _lastWordAt;
    _combo = last != null && now.difference(last) < _comboWindow ? _combo + 1 : 0;
    _lastWordAt = now;
    if (letters >= 5) return _play('success_long.wav', volume: 0.85);
    return _play('success_${_combo.clamp(0, 4)}.wav');
  }

  /// ניסיון מילה לא תקין/כפול - צליל שלילי קצר, לא מציק. שובר את הרצף.
  Future<void> playError() {
    _combo = 0;
    _lastWordAt = null;
    return _play('error_word.wav', volume: 0.6);
  }

  /// אות נוספה לנתיב בזמן גרירה - כל אות עולה צליל אחד בסולם
  /// ([index] = מיקום האות במילה, 0 = הראשונה).
  Future<void> playTileTap([int index = 0]) => _play('tile_${index.clamp(0, 11)}.wav', volume: 0.5);

  /// תחילת שלב בלי ספירה לאחור - "יאללה!" קצר כשהטיימר מתחיל.
  Future<void> playLevelStart() => _play('level_start.wav', volume: 0.75);

  /// ספירה לאחור 3-2-1-יאללה (מסונכרן ל-StartCountdown: צעד כל 700ms).
  Future<void> playCountdown() => _play('countdown.wav', volume: 0.75);

  /// ערבוב אותיות הלוח - מפל בועות קטן.
  Future<void> playShuffle() => _play('shuffle.wav', volume: 0.7);

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

  /// לחיצה על תיבה סגורה - הצליל עולה עם כל לחיצה ([step] 0..3).
  Future<void> playCharge(int step) => _play('charge_${step.clamp(0, 3)}.wav', volume: 0.7);

  /// התיבה עלתה דרגת נדירות.
  Future<void> playRarityUp() => _play('rarity_up.wav', volume: 0.8);

  /// פתיחת פרס - פנפרה שגדלה לפי הדרגה (0=רגיל ... 4=אגדי).
  Future<void> playReveal(int rarityIndex) {
    final file = switch (rarityIndex) {
      <= 1 => 'reveal_common.wav',
      2 => 'reveal_rare.wav',
      3 => 'reveal_epic.wav',
      _ => 'reveal_legendary.wav',
    };
    return _play(file, volume: 0.85);
  }

  /// זיקוק מתפוצץ.
  Future<void> playFirework() => _play('firework.wav', volume: 0.5);

  /// "קליק" של המחוג בגלגל המזל.
  Future<void> playWheelTick() => _play('wheel_tick.wav', volume: 0.35);

  /// איסוף פרס.
  Future<void> playCollect() => _play('collect.wav', volume: 0.75);

  void dispose() {
    for (final p in _poolStorage ?? const <AudioPlayer>[]) {
      p.dispose();
    }
  }
}
