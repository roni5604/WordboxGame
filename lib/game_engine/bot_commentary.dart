import 'dart:math';

/// מצב רוח של הערה - קובע את האנימציה והצבע של הבועה.
enum CommentMood { cheeky, impressed, nervous, thinking, friendly }

class BotComment {
  final String botName;
  final String text;
  final CommentMood mood;

  const BotComment(this.botName, this.text, this.mood);
}

/// "פרשן" התחרות: הבוטים מעירים הערות קצרות לפי מה שקורה במשחק - מילה
/// ארוכה של השחקן/ית, עקיפה, שקט ארוך, דקה אחרונה... **מעט** הערות, בזמן
/// הנכון: מרווח מינימלי בין הערות ותקרה לכל תחרות, כדי שזה יוסיף רגש
/// ולא יפריע. לוגיקה טהורה - בלי UI, כדי שאפשר לבדוק אותה.
class BotCommentary {
  BotCommentary({Random? random, this.maxComments = 5, this.cooldown = const Duration(seconds: 14)})
    : _random = random ?? Random();

  final Random _random;
  final int maxComments;
  final Duration cooldown;

  int _count = 0;
  Duration? _lastAt;
  final Set<String> _onceKeys = {};
  String? _leader;
  bool _lastMinuteSaid = false;

  int get count => _count;

  bool _canSpeak(Duration now) {
    if (_count >= maxComments) return false;
    final last = _lastAt;
    return last == null || now - last >= cooldown;
  }

  BotComment? _say(Duration now, String bot, CommentMood mood, List<String> options, {String? onceKey}) {
    if (onceKey != null && !_onceKeys.add(onceKey)) return null;
    if (!_canSpeak(now)) return null;
    _count++;
    _lastAt = now;
    return BotComment(bot, options[_random.nextInt(options.length)], mood);
  }

  /// השחקן/ית מצא/ה מילה. [letters] - אורך המילה.
  BotComment? onHumanWord(
    Duration now, {
    required int letters,
    required String displayWord,
    required List<String> bots,
  }) {
    if (bots.isEmpty || letters < 5) return null;
    final bot = bots[_random.nextInt(bots.length)];
    return _say(now, bot, CommentMood.impressed, [
      'וואו, "$displayWord"! איך ראית את זה?',
      '$letters אותיות?! את/ה בכושר 🔥',
      'אוקיי, "$displayWord" זה כבר מרשים 😮',
      'רגע רגע... "$displayWord"? לא ראיתי!',
    ]);
  }

  /// בוט מצא מילה.
  BotComment? onBotWord(Duration now, {required String bot, required int letters}) {
    if (letters >= 5) {
      return _say(now, bot, CommentMood.cheeky, [
        'מצאתי מילה של $letters אותיות 😎',
        'יש! מילה ארוכה בכיס',
        'תנסו למצוא את מה שאני מצאתי 😏',
      ]);
    }
    return null;
  }

  /// בדיקה כללית בכל שנייה: עקיפות, שקט, דקה אחרונה.
  BotComment? onTick(
    Duration now, {
    required Duration remaining,
    required int humanScore,
    required Map<String, int> botScores,
    required Duration humanIdle,
    String? stuckBot,
  }) {
    if (botScores.isEmpty) return null;
    final topBot = botScores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final leader = humanScore > topBot.value ? 'human' : topBot.key;
    final previous = _leader;
    _leader = leader;

    // פתיחה ידידותית, פעם אחת, אחרי כמה שניות.
    if (now >= const Duration(seconds: 4) && now < const Duration(seconds: 12)) {
      final c = _say(now, botScores.keys.first, CommentMood.friendly, [
        'בהצלחה! שיהיה משחק טוב 🤝',
        'מוכנים? אני כבר מחפש/ת...',
        'בואו נראה מי מהיר יותר 😄',
      ], onceKey: 'hello');
      if (c != null) return c;
    }

    if (previous != null && previous != leader) {
      if (leader == 'human') {
        return _say(now, topBot.key, CommentMood.nervous, [
          'אוי, עקפת אותי! 😅',
          'לא לא לא... חכה/י רגע!',
          'אני חוזר/ת, אל תתרגל/י 😤',
        ]);
      }
      return _say(now, leader, CommentMood.cheeky, ['עקפתי! 😎', 'מקום ראשון, סליחה 😏', 'תפסתי את המקום הראשון!']);
    }

    if (!_lastMinuteSaid && remaining <= const Duration(seconds: 20) && remaining > Duration.zero) {
      _lastMinuteSaid = true;
      final gap = humanScore - topBot.value;
      final c = gap >= 0
          ? _say(now, topBot.key, CommentMood.nervous, [
              'עוד 20 שניות... אני עוד יכול/ה להשיג אותך!',
              'זה הולך להיות צמוד! ⏱️',
            ])
          : _say(now, topBot.key, CommentMood.cheeky, ['20 שניות! תספיק/י להשיג אותי? 😏', 'הזמן אוזל... ⏳']);
      if (c != null) return c;
    }

    if (stuckBot != null && _random.nextDouble() < 0.5) {
      final c = _say(now, stuckBot, CommentMood.thinking, [
        'הממ... הלוח הזה קשה 🤔',
        'רגע, אני חושב/ת...',
        'איפה מסתתרות המילים פה?',
      ], onceKey: 'stuck-$stuckBot');
      if (c != null) return c;
    }

    if (humanIdle >= const Duration(seconds: 18)) {
      return _say(now, botScores.keys.first, CommentMood.friendly, [
        'טיפ: מילים של 2-3 אותיות זה התחלה טובה 💡',
        'נסו להתחיל מאות בפינה 😉',
      ], onceKey: 'idle-${now.inSeconds ~/ 40}');
    }
    return null;
  }
}
