import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/cosmetics/cosmetic_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';
import '../ads/rewarded_hint_dialog.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/level_board_builder.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../game_engine/rewards/reward_tables.dart';
import '../../game_engine/word_finder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/common_word_pool_provider.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/level_boards_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'widgets/current_word_badge.dart';
import 'widgets/found_words_panel.dart';
import 'widgets/grid_board.dart';
import 'widgets/mascot_widget.dart';
import 'widgets/pause_menu.dart';
import 'widgets/timer_bar.dart';
import 'widgets/words_goal_panel.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/platform/browser_back_guard.dart';
import '../../core/feedback/haptics.dart';

/// תוצאת שלב שהושלם - מועברת למסך התוצאה דרך go_router `extra`.
class GameScreenResult extends Equatable {
  final int score;
  final int stars;
  final int foundWordsCount;
  final int totalPossibleWords;
  final int totalPossibleScore;
  final List<String> foundWordsDisplay;
  final int coinsEarned;

  /// סוג השלב שהושלם (רגיל/מאסטר/פינאלה) - ראו [LevelKind]. קובע אילו
  /// באנרים/חגיגות מוצגים במסך התוצאה (level_result_screen.dart).
  final LevelKind levelKind;

  /// true אם זה שלב "פינאלה" (ראו [LevelConfig.isWorldFinale]) שהושלם
  /// בהצלחה (לפחות כוכב אחד) - מפעיל את מסך "עולם חדש נפתח!" המורחב.
  bool get isWorldFinale => levelKind == LevelKind.worldFinale;
  bool get isMasterLevel => levelKind == LevelKind.master;

  final int bonusCoins;
  final int bonusHints;
  final String? newTierTitle;
  final int? newGridSize;

  /// פרס תיבת מזל שנפתחה בסיום השלב הזה (כל 7 שלבים, פעם ראשונה בלבד) -
  /// null אם לא רלוונטי לשלב הזה.
  final LuckyBoxReward? luckyBoxReward;

  /// פרס גלגל מזל שהוגרל בסיום שלב פינאלה (פעם ראשונה בלבד) - null אם
  /// לא רלוונטי לשלב הזה.
  final FortuneWheelPrize? wheelPrize;

  /// האינדקס של [wheelPrize] בתוך [RewardTables.wheelPrizes] - נדרש כדי
  /// שאנימציית סיבוב הגלגל (fortune_wheel_dialog.dart) תעצור בדיוק על
  /// המקטע הנכון.
  final int wheelPrizeIndex;

  /// true אם השלב הסתיים כי הושג יעד הניקוד ([LevelConfig.scoreRequired])
  /// לפני שהזמן נגמר (השלב מסתיים מיידית באותו רגע) - מפעיל חגיגת "סיים
  /// לפני הזמן!" מיוחדת במסך התוצאה.
  final bool finishedEarly;

  /// כמה שניות נשארו על השעון בזמן שהשלב הסתיים - רלוונטי רק כשסיים
  /// לפני הזמן ([finishedEarly]).
  final int secondsLeftWhenFinished;

  const GameScreenResult({
    required this.score,
    required this.stars,
    required this.foundWordsCount,
    required this.totalPossibleWords,
    required this.totalPossibleScore,
    required this.foundWordsDisplay,
    required this.coinsEarned,
    this.levelKind = LevelKind.normal,
    this.bonusCoins = 0,
    this.bonusHints = 0,
    this.newTierTitle,
    this.newGridSize,
    this.luckyBoxReward,
    this.wheelPrize,
    this.wheelPrizeIndex = 0,
    this.finishedEarly = false,
    this.secondsLeftWhenFinished = 0,
  });

  @override
  List<Object?> get props => [
    score,
    stars,
    foundWordsCount,
    totalPossibleWords,
    totalPossibleScore,
    coinsEarned,
    levelKind,
    bonusCoins,
    bonusHints,
    newTierTitle,
    newGridSize,
    luckyBoxReward,
    wheelPrize,
    wheelPrizeIndex,
    finishedEarly,
    secondsLeftWhenFinished,
  ];
}

class GameScreen extends ConsumerStatefulWidget {
  final int levelNumber;

  const GameScreen({super.key, required this.levelNumber});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with WidgetsBindingObserver {
  // הגרלת "כוכב מזל" (ראו _finishLevel).
  final Random _dropRandom = Random();
  GameSession? _session;
  late LevelConfig _config;
  Duration _remaining = Duration.zero;
  Timer? _ticker;
  final _boardKey = GlobalKey<GridBoardState>();

  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;

  bool _finished = false;
  bool _paused = false;
  bool _adHintBusy = false;
  int? _lastWarningSecond;
  int _lastCelebratedStars = 0;

  /// המילה שנבנית כרגע תוך כדי גרירה על הלוח (ריקה כשאין גרירה פעילה) -
  /// מוצגת בבועה למעלה, כדי שתמיד יהיה ברור אילו אותיות נבחרו עד כה.
  String _draggingWord = '';

  String? _tutorialWord;
  List<GridPosition>? _tutorialPath;
  bool _showTutorialOverlay = false;

  @override
  void initState() {
    super.initState();
    _config = CampaignLevels.byLevelNumber(widget.levelNumber);
    _remaining = _config.timeLimit;
    WidgetsBinding.instance.addObserver(this);
    _initSession();
  }

  /// יציאה מהאפליקציה באמצע שלב (שיחה נכנסת, מעבר לאפליקציה אחרת) -
  /// עוצרים את השעון ומציגים את תפריט ההשהיה כשחוזרים.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  Future<void> _pause() async {
    if (_paused || _finished || _session == null || _adHintBusy) return;
    final wasRunning = _ticker != null;
    _ticker?.cancel();
    _ticker = null;
    setState(() => _paused = true);
    final choice = await showPauseMenu(
      context,
      subtitle: 'שלב ${widget.levelNumber} · ${_session?.score ?? 0} נקודות',
      exitWarning: 'יציאה עכשיו לא תשמור את ההתקדמות בשלב הזה.',
    );
    if (!mounted) return;
    switch (choice) {
      case PauseChoice.resume:
        setState(() => _paused = false);
        if (wasRunning && !_finished && _remaining > Duration.zero) _startTimer();
      case PauseChoice.restart:
        _finished = true;
        context.pushReplacement('/level/${widget.levelNumber}/play');
      case PauseChoice.exit:
        _finished = true;
        context.go('/campaign');
    }
  }

  Future<void> _initSession() async {
    final dictionary = await ref.read(dictionaryLoadProvider.future);

    // לוחות קבועים וזהים לכל המשתמשים/ות (ראו tool/generate_level_boards.dart
    // ו-lib/game_engine/level_board_builder.dart) - נבנו מראש סביב מילים
    // מוכרות/נוחות, בקושי עולה הדרגתי. שלבים שמעבר לטווח שנבנה מראש עדיין
    // נבנים דטרמיניסטית (לפי מספר השלב), רק לא ממופתחים build-time.
    final pregenerated = await ref.read(levelBoardsProvider.future);
    final pre = pregenerated[widget.levelNumber];

    List<List<String>> letters;
    if (pre != null) {
      letters = pre.letters;
      _tutorialWord = pre.tutorialWord;
      _tutorialPath = pre.tutorialPath;
    } else {
      final weights = await ref.read(letterFrequencyProvider.future);
      final commonWords = await ref.read(commonWordPoolProvider.future);
      final builder = LevelBoardBuilder(trie: dictionary.trie, letterWeights: weights, commonWords: commonWords);
      letters = builder.buildForLevel(_config).board.letters;
    }

    final possibleWords = WordFinder(dictionary.trie).findAllWords(letters);
    final board = GeneratedBoard(letters: letters, possibleWords: possibleWords, size: _config.gridSize);
    final session = GameSession(config: _config, board: board, trie: dictionary.trie);

    if (!mounted) return;
    setState(() => _session = session);
    await _maybeShowTutorial();
  }

  /// בשלב 1 בלבד (ורק בפעם הראשונה): לפני שהטיימר מתחיל לרוץ, מדגישים
  /// (בזהב, באופן "דביק" - בלי להיעלם אוטומטית) את הנתיב של מילה מוכרת
  /// שהוצבה בכוונה על הלוח, ומציגים בועת טקסט מנחה עם כפתור התחלה.
  Future<void> _maybeShowTutorial() async {
    final word = _tutorialWord;
    final path = _tutorialPath;
    if (widget.levelNumber != 1 || word == null || path == null) {
      _startTimer();
      return;
    }

    final profile = await ref.read(playerProfileProvider.notifier).ensureLoaded();
    if (profile.level1TutorialSeen) {
      _startTimer();
      return;
    }

    if (!mounted) return;
    setState(() => _showTutorialOverlay = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boardKey.currentState?.showHint(path, duration: null);
    });
  }

  void _dismissTutorial() {
    setState(() => _showTutorialOverlay = false);
    _boardKey.currentState?.clearHint();
    ref.read(playerProfileProvider.notifier).setLevel1TutorialSeen();
    _startTimer();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(milliseconds: 100);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          _finishLevel();
        } else {
          // "טיק" אזהרה בכל שנייה שלמה כשנשארו פחות מ-20% מהזמן (אותו סף
          // כמו "urgent" בפס הטיימר) - כך שהאפקט מתאים גם לשלבים קצרים.
          final secondsLeft = _remaining.inSeconds;
          final urgent = _remaining.inSeconds < (_config.timeLimit.inSeconds * 0.2);
          if (urgent && secondsLeft != _lastWarningSecond) {
            _lastWarningSecond = secondsLeft;
            ref.read(soundServiceProvider).playTimerWarning();
          }
        }
      });
    });
  }

  void _showBanner(String text, {bool isError = false}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerText = text;
      _bannerIsError = isError;
    });
    _bannerTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  void _onWordChanging(String word) {
    if (_draggingWord == word) return;
    setState(() => _draggingWord = word);
  }

  /// חגיגת-ביניים כשעולה למספר כוכבים גבוה יותר במהלך השלב (לא רק
  /// בסיום) - צליל שמח + רטט + הודעה, כך שברור לשחקן/ית בזמן אמת "כמה
  /// כוכבים כבר בכיס". מתוזמן קצת אחרי הודעת "מילה נמצאה!" כדי לא
  /// לדרוס אותה (שתי ההודעות חולקות את אותו banner/timer).
  void _celebrateStarGained(int stars) {
    ref.read(soundServiceProvider).playStarGained();
    Haptics.heavy();
    final starsText = '⭐' * stars;
    Future.delayed(const Duration(milliseconds: 950), () {
      if (!mounted || _finished) return;
      _showBanner('$starsText ${stars >= 3 ? "מושלם! כל הכבוד!" : "כוכב חדש!"}');
    });
  }

  Future<bool> _ensureCoins(int cost) async {
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return false;
    if (profile.coins < cost) {
      _showNeedCoins();
      return false;
    }
    final spent = await ref.read(playerProfileProvider.notifier).spendCoins(cost);
    if (!spent) {
      _showNeedCoins();
      return false;
    }
    return true;
  }

  void _showNeedCoins() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('אין מספיק מטבעות'),
        action: SnackBarAction(
          label: 'לחנות',
          onPressed: () {
            if (mounted) context.push('/store');
          },
        ),
      ),
    );
  }

  Future<void> _revealLetter() async {
    final session = _session;
    if (session == null || _finished) return;
    final pos = session.letterHintPosition();
    if (pos == null) {
      _showBanner('כבר מצאתם את כל המילים! 🎉');
      return;
    }
    if (!await _ensureCoins(CoinCosts.revealLetter)) return;
    if (!mounted) return;
    ref.read(soundServiceProvider).playHint();
    _boardKey.currentState?.showHint([pos], duration: const Duration(seconds: 4));
    _showBanner('אות נחשפה');
  }

  Future<void> _shuffleBoard() async {
    final session = _session;
    if (session == null || _finished) return;
    if (!await _ensureCoins(CoinCosts.shuffle)) return;
    if (!mounted) return;
    session.reshuffleLetters(Random());
    _boardKey.currentState?.clearHint();
    ref.read(soundServiceProvider).playSuccess();
    setState(() {});
    _showBanner('האותיות עורבבו');
  }

  Future<void> _confirmSkip() async {
    if (_finished) return;
    final cost = CoinCosts.skipLevel(widget.levelNumber);
    final confirmed = await showConfirmDialog(
      context,
      title: 'לדלג על השלב?',
      message: 'הדילוג עולה $cost מטבעות, נותן כוכב אחד ופותח את השלב הבא.',
      confirmLabel: 'דילוג · $cost מטבעות',
      confirmPalette: CandyPalette.gold,
    );
    if (!confirmed || !mounted || _finished) return;
    final ok = await ref.read(playerProfileProvider.notifier).skipLevel(levelNumber: widget.levelNumber, cost: cost);
    if (!ok || !mounted) {
      _showNeedCoins();
      return;
    }
    _finished = true;
    _ticker?.cancel();
    ref.read(soundServiceProvider).playCoin();
    final next = widget.levelNumber + 1;
    if (next > CampaignLevels.totalLevels) {
      context.go('/campaign');
    } else {
      context.pushReplacement('/level/$next/intro');
    }
  }

  Future<void> _useHint() async {
    final session = _session;
    if (session == null || _finished) return;

    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return;

    final word = session.hintForUnfoundWord();
    if (word == null) {
      _showBanner('כבר מצאתם את כל המילים! 🎉');
      return;
    }

    if (profile.hints <= 0) {
      final granted = await _tryGrantHintFromAd();
      if (!granted || !mounted) return;
    }

    final used = await ref.read(playerProfileProvider.notifier).useHint();
    if (!used || !mounted) return;

    ref.read(soundServiceProvider).playHint();
    _boardKey.currentState?.showHint(word.path);
    _showBanner('💡 נסו את המילה: ${word.displayWord}');
  }

  /// כשנגמרו הרמזים: מציעים צפייה בפרסומת לרמז אחד (גם לאורחים), עד 3 ביום.
  /// הטיימר נעצר לכל אורך הדיאלוג והמודעה.
  Future<bool> _tryGrantHintFromAd() async {
    if (_adHintBusy) return false;
    final ads = ref.read(adsGatewayProvider);
    final authUser = ref.read(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;

    if (!ads.isSupported) {
      _showBanner(isGuest ? 'נגמרו הרמזים' : 'נגמרו הרמזים - אפשר לקנות עוד בחנות', isError: true);
      return false;
    }

    _adHintBusy = true;
    final wasRunning = _ticker != null;
    _ticker?.cancel();
    _ticker = null;
    try {
      await ads.ensureInitialized();
      if (!mounted) return false;
      if (!ads.canRequestAds || !ads.isRewardedReady) {
        _showBanner(isGuest ? 'אין פרסומת כרגע' : 'אין פרסומת כרגע - אפשר לקנות בחנות', isError: true);
        return false;
      }
      if (ads.adHintsRemaining <= 0) {
        _showBanner(
          isGuest ? 'נגמרו הרמזים מפרסומות להיום' : 'נגמרו הרמזים מפרסומות להיום - אפשר לקנות בחנות',
          isError: true,
        );
        return false;
      }

      final watch = await showRewardedHintDialog(context, remainingToday: ads.adHintsRemaining);
      if (!mounted || !watch) return false;

      final earned = await ads.showRewarded();
      if (!mounted) return false;
      if (!earned) {
        _showBanner('לא הושלמה הצפייה, אין רמז', isError: true);
        return false;
      }

      await ref.read(playerProfileProvider.notifier).grantHints(1);
      await ads.recordAdHintGranted();
      ref.read(soundServiceProvider).playCoin();
      return true;
    } finally {
      _adHintBusy = false;
      if (wasRunning && mounted && !_finished && _remaining > Duration.zero && _ticker == null) {
        _startTimer();
      }
    }
  }

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    if (session == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess();
        Haptics.success();
        _showBanner('${result.displayWord}  +${result.pointsAwarded}');
        setState(() {});
        final newStars = session.currentStars;
        if (newStars > _lastCelebratedStars) {
          _lastCelebratedStars = newStars;
          _celebrateStarGained(newStars);
        }
        // ברגע שהושג יעד הניקוד - השלב מסתיים מיידית (3 כוכבים, חגיגת
        // "סיים לפני הזמן!"), בלי לחכות שהזמן יגמר או שכל מילות הלוח
        // יימצאו.
        if (session.hasReachedScoreGoal || session.isFullyCompleted) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _finishLevel(earlyFinish: session.hasReachedScoreGoal),
          );
        }
        break;
      case WordSubmitStatus.duplicate:
        ref.read(soundServiceProvider).playError();
        Haptics.error();
        _showBanner('כבר מצאת את "${result.displayWord}"', isError: true);
        _boardKey.currentState?.flashError();
        break;
      case WordSubmitStatus.invalidWord:
        ref.read(soundServiceProvider).playError();
        Haptics.error();
        _showBanner('לא נמצאה מילה כזו', isError: true);
        _boardKey.currentState?.flashError();
        break;
      case WordSubmitStatus.tooShort:
      case WordSubmitStatus.invalidPath:
        _boardKey.currentState?.flashError();
        break;
    }
  }

  Future<void> _finishLevel({bool earlyFinish = false}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final session = _session;
    if (session == null) return;

    final stars = session.currentStars;
    final secondsLeftWhenFinished = _remaining.inSeconds;
    final worldIndex = _config.tier.index;

    // תגמול חד-פעמי (תיבת מזל / גלגל מזל) יוענק רק בפעם הראשונה שהשלב
    // הזה מושלם בפועל - לא בכל שיחזור שלו (ראו
    // PlayerProfileNotifier.isFirstCompletion).
    final notifier = ref.read(playerProfileProvider.notifier);
    final isFirstCompletion = notifier.isFirstCompletion(widget.levelNumber);
    final earnedAnyStars = stars >= 1;

    // שלב פינאלה (האחרון בעולם) שהושלם בהצלחה - פותח את העולם הבא,
    // מזכה בבונוס נדיב, ומפעיל חגיגה מורחבת + גלגל מזל במסך התוצאה.
    final isWorldFinale = _config.isWorldFinale && earnedAnyStars;
    final isMaster = _config.isMasterLevel && earnedAnyStars;
    const finaleBonusCoins = 75;
    const finaleBonusHints = 3;

    final baseCoins = stars * 10 + session.foundWordsCount * 2;
    final coinsEarned = isWorldFinale ? baseCoins + finaleBonusCoins : (isMaster ? baseCoins * 2 : baseCoins);

    final actualCoinsEarned = await notifier.completeLevel(
      levelNumber: widget.levelNumber,
      stars: stars,
      score: session.score,
      coinsEarned: coinsEarned,
    );

    if (isWorldFinale) {
      await notifier.grantHints(finaleBonusHints);
    }

    // תיבת מזל: כל 7 שלבים גלובליים, פעם ראשונה בלבד ובתנאי שהושג לפחות
    // כוכב אחד (כמו כל תגמול אחר בשלב).
    LuckyBoxReward? luckyBoxReward;
    if (isFirstCompletion && earnedAnyStars && widget.levelNumber % RewardTables.luckyBoxLevelInterval == 0) {
      luckyBoxReward = await notifier.openLuckyDrop(worldIndex: worldIndex);
    } else if (isFirstCompletion && stars == 3 && !isWorldFinale && _dropRandom.nextDouble() < RewardTables.starDropChance) {
      // "כוכב מזל": הפתעה לא צפויה על שלב מושלם - חיזוק אקראי שגורם לרצות
      // לשחק עוד שלב ולהשיג שוב 3 כוכבים.
      luckyBoxReward = await notifier.openLuckyDrop(worldIndex: worldIndex, kind: DropKind.starDrop);
    }

    // גלגל מזל: רק בסיום שלב פינאלה, פעם ראשונה בלבד.
    FortuneWheelPrize? wheelPrize;
    int wheelPrizeIndex = 0;
    if (isFirstCompletion && isWorldFinale) {
      final (index, prize) = RewardTables.rollWheelPrize(worldIndex: worldIndex);
      wheelPrize = prize;
      wheelPrizeIndex = index;
      await notifier.grantWheelPrize(prize);
    }

    if (!mounted) return;

    final result = GameScreenResult(
      score: session.score,
      stars: stars,
      foundWordsCount: session.foundWordsCount,
      totalPossibleWords: session.totalPossibleWords,
      totalPossibleScore: session.totalPossibleScore,
      foundWordsDisplay: session.foundNormalizedWords.map((w) => HebrewTrie.toDisplayWord(w)).toList(),
      coinsEarned: actualCoinsEarned,
      levelKind: _config.kind,
      bonusCoins: isWorldFinale ? finaleBonusCoins : 0,
      bonusHints: isWorldFinale ? finaleBonusHints : 0,
      newTierTitle: isWorldFinale ? _nextWorldTitle() : null,
      newGridSize: isWorldFinale ? _nextWorldGridSize() : null,
      luckyBoxReward: luckyBoxReward,
      wheelPrize: wheelPrize,
      wheelPrizeIndex: wheelPrizeIndex,
      finishedEarly: earlyFinish,
      secondsLeftWhenFinished: secondsLeftWhenFinished,
    );

    context.pushReplacement('/level/${widget.levelNumber}/result', extra: result);
  }

  /// שם/גודל העולם הבא (לצורך "עולם חדש נפתח!" בסיום שלב פינאלה) - השלב
  /// שאחרי הפינאלה הנוכחית, אם קיים.
  String? _nextWorldTitle() {
    if (widget.levelNumber >= CampaignLevels.all.length) return null;
    return CampaignLevels.byLevelNumber(widget.levelNumber + 1).tier.titleHe;
  }

  int? _nextWorldGridSize() {
    if (widget.levelNumber >= CampaignLevels.all.length) return null;
    return CampaignLevels.byLevelNumber(widget.levelNumber + 1).gridSize;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final worldIndex = _config.tier.index;
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final boardSkin = CosmeticCatalog.boardById(profile?.boardSkinId);
    final letterSkin = CosmeticCatalog.letterById(profile?.letterSkinId);
    final markerSkin = CosmeticCatalog.markerById(profile?.markerSkinId);

    return BrowserBackGuard(
      onBlocked: _pause,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          // "חזרה" של המערכת (החלקה מהקצה / כפתור אחורה) פותחת השהיה במקום
          // לצאת מהשלב בטעות.
          if (!didPop) _pause();
        },
        child: TopBarTint(
          color: AppColors.gradientForWorldIndex(CampaignLevels.byLevelNumber(widget.levelNumber).tier.index).first,
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.gradientForWorldIndex(worldIndex),
                ),
              ),
              child: SafeArea(
                child: session == null
                    ? const _LoadingBoard()
                    : Column(
                        children: [
                          _GameHeader(
                            levelNumber: widget.levelNumber,
                            score: session.score,
                            onPause: _pause,
                            onHint: _useHint,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TimerBar(
                              progress: _remaining.inMilliseconds / _config.timeLimit.inMilliseconds,
                              urgent: _remaining.inSeconds < (_config.timeLimit.inSeconds * 0.2),
                              secondsLeft: _remaining.inSeconds,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: WordsGoalPanel(
                              score: session.score,
                              required: _config.scoreRequired,
                              stars: session.currentStars,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _PowerRow(
                              onReveal: _revealLetter,
                              onShuffle: _shuffleBoard,
                              onSkip: _confirmSkip,
                              skipCost: CoinCosts.skipLevel(widget.levelNumber),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CurrentWordBadge(word: _draggingWord),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // ריבוע גדול ככל האפשר שעדיין נכנס לגמרי
                                      // בשטח הפנוי - כך כל השורות תמיד גלויות.
                                      final side = constraints.maxWidth < constraints.maxHeight
                                          ? constraints.maxWidth
                                          : constraints.maxHeight;
                                      return Center(
                                        child: SizedBox(
                                          width: side,
                                          height: side,
                                          child: PausableBoard(
                                            paused: _paused,
                                            child: GridBoard(
                                              key: _boardKey,
                                              enabled: !_paused,
                                              letters: session.board.letters,
                                              onPathSubmitted: _onPathSubmitted,
                                              isPathAcceptable: session.wouldAccept,
                                              onWordChanged: _onWordChanging,
                                              boardSkin: boardSkin,
                                              letterSkin: letterSkin,
                                              markerSkin: markerSkin,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_bannerText != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child:
                                        Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: _bannerIsError ? AppColors.error : Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                                              ),
                                              child: Text(
                                                _bannerText!,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 18,
                                                  color: _bannerIsError ? Colors.white : AppColors.success,
                                                ),
                                              ),
                                            )
                                            .animate(key: ValueKey(_bannerText))
                                            .fadeIn()
                                            .moveY(begin: 10, end: 0, duration: 200.ms),
                                  ),
                                if (_showTutorialOverlay && _tutorialWord != null)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 8,
                                    child: _TutorialCard(
                                      word: HebrewTrie.toDisplayWord(_tutorialWord!),
                                      onStart: _dismissTutorial,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: FoundWordsPanel(
                              words: session.foundNormalizedWords.map((w) => HebrewTrie.toDisplayWord(w)).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerRow extends StatelessWidget {
  final VoidCallback onReveal;
  final VoidCallback onShuffle;
  final VoidCallback onSkip;
  final int skipCost;

  const _PowerRow({required this.onReveal, required this.onShuffle, required this.onSkip, required this.skipCost});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PowerButton(
            icon: Icons.font_download_rounded,
            label: 'אות · ${CoinCosts.revealLetter}',
            onPressed: onReveal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PowerButton(icon: Icons.shuffle_rounded, label: 'ערבוב · ${CoinCosts.shuffle}', onPressed: onShuffle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PowerButton(icon: Icons.skip_next_rounded, label: 'דילוג · $skipCost', onPressed: onSkip),
        ),
      ],
    );
  }
}

class _PowerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PowerButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.primaryDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHeader extends ConsumerWidget {
  final int levelNumber;
  final int score;
  final VoidCallback onPause;
  final VoidCallback onHint;

  const _GameHeader({required this.levelNumber, required this.score, required this.onPause, required this.onHint});

  /// רמזים שמורים לחשבונות אמיתיים - לאורח/ת מציגים הזמנה להירשם במקום
  /// לצרוך רמז, כדי לא לתת לאורח/ת גישה ל"אפשרות רמזים" בכלל.
  void _showGuestHintPrompt(BuildContext context) {
    showGameDialog<void>(
      context: context,
      builder: (dialogContext) => GameDialog(
        title: 'רמזים שמורים לרשומים',
        ribbon: CandyPalette.gold,
        message:
            'הרשמו בחינם עם Google, Apple, Facebook או מייל וקבלו רמזי מתנה '
            'מיד ובונוס יומי - בלי לאבד את ההתקדמות הנוכחית שלכם.',
        actions: [
          CandyButton(
            label: 'הרשמה',
            palette: CandyPalette.green,
            height: 54,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/auth');
            },
          ),
          CandyButton(
            label: 'אחר כך',
            palette: CandyPalette.white,
            height: 48,
            fontSize: 16,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hints = ref.watch(playerProfileProvider).valueOrNull?.hints ?? 0;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Row(
        children: [
          CandyIconButton(icon: Icons.pause_rounded, size: 42, tooltip: 'השהיה', onPressed: onPause),
          const SizedBox(width: 10),
          Text(
            'שלב $levelNumber',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
            ),
          ),
          const Spacer(),
          Pressable(
            onTap: isGuest ? () => _showGuestHintPrompt(context) : onHint,
            semanticLabel: 'רמז',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE27A), Color(0xFFFFB700)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0xFFC77F00), offset: Offset(0, 3))],
              ),
              child: Row(
                children: [
                  Icon(
                    isGuest ? Icons.lock_outline_rounded : Icons.lightbulb_rounded,
                    color: const Color(0xFF5A3300),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isGuest ? 'הרשמה' : '$hints',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5A3300)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                child: child,
              ),
              child: Text(
                '$score נק׳',
                key: ValueKey(score),
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// בועת ההדרכה המוטבעת בתחילת שלב 1: מסבירה שיש להדגיש/לגרור בין
/// האותיות המודגשות בזהב (ראו [GridBoardState.showHint]) ליצירת המילה
/// המוצגת, וכפתור להתחלת הטיימר בפועל.
class _TutorialCard extends StatelessWidget {
  final String word;
  final VoidCallback onStart;

  const _TutorialCard({required this.word, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.star),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'גררו אצבע בין האותיות המסומנות בזהב ליצירת המילה "$word"',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CandyButton(
            label: 'הבנתי, בואו נתחיל!',
            icon: Icons.play_arrow_rounded,
            palette: CandyPalette.green,
            height: 54,
            fontSize: 18,
            onPressed: onStart,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.3, end: 0);
  }
}

class _LoadingBoard extends StatelessWidget {
  const _LoadingBoard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MascotWidget(mood: MascotMood.idle, size: 100),
          SizedBox(height: 16),
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text('בונים לוח מילים...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
