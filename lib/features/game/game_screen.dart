import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/level_board_builder.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../game_engine/word_finder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/common_word_pool_provider.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/level_boards_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'widgets/found_words_panel.dart';
import 'widgets/grid_board.dart';
import 'widgets/mascot_widget.dart';
import 'widgets/timer_bar.dart';

/// תוצאת שלב שהושלם - מועברת למסך התוצאה דרך go_router `extra`.
class GameScreenResult extends Equatable {
  final int score;
  final int stars;
  final int foundWordsCount;
  final int totalPossibleWords;
  final int totalPossibleScore;
  final List<String> foundWordsDisplay;
  final int coinsEarned;

  /// אבן-דרך: true אם השלב הזה הוא שלב "עולם חדש" (ראו
  /// [LevelConfig.isMilestoneLevel]) שהושלם בהצלחה (לפחות כוכב אחד) -
  /// מפעיל את מסך החגיגה המורחב ב-level_result_screen.dart.
  final bool isMilestoneLevel;
  final int bonusCoins;
  final int bonusHints;
  final String? newTierTitle;
  final int? newGridSize;

  const GameScreenResult({
    required this.score,
    required this.stars,
    required this.foundWordsCount,
    required this.totalPossibleWords,
    required this.totalPossibleScore,
    required this.foundWordsDisplay,
    required this.coinsEarned,
    this.isMilestoneLevel = false,
    this.bonusCoins = 0,
    this.bonusHints = 0,
    this.newTierTitle,
    this.newGridSize,
  });

  @override
  List<Object?> get props => [
        score,
        stars,
        foundWordsCount,
        totalPossibleWords,
        totalPossibleScore,
        coinsEarned,
        isMilestoneLevel,
        bonusCoins,
        bonusHints,
        newTierTitle,
        newGridSize,
      ];
}

class GameScreen extends ConsumerStatefulWidget {
  final int levelNumber;

  const GameScreen({super.key, required this.levelNumber});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  GameSession? _session;
  late LevelConfig _config;
  Duration _remaining = Duration.zero;
  Timer? _ticker;
  final _boardKey = GlobalKey<GridBoardState>();

  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;

  bool _finished = false;
  int? _lastWarningSecond;

  String? _tutorialWord;
  List<GridPosition>? _tutorialPath;
  bool _showTutorialOverlay = false;

  @override
  void initState() {
    super.initState();
    _config = CampaignLevels.byLevelNumber(widget.levelNumber);
    _remaining = _config.timeLimit;
    _initSession();
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
      final builder = LevelBoardBuilder(
        trie: dictionary.trie,
        letterWeights: weights,
        commonWords: commonWords,
      );
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
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(milliseconds: 100);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          _finishLevel();
        } else {
          // "טיק" אזהרה בכל שנייה שלמה בחמש השניות האחרונות בלבד.
          final secondsLeft = _remaining.inSeconds;
          if (secondsLeft <= 5 && secondsLeft != _lastWarningSecond) {
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
      _showBanner('נגמרו הרמזים - אפשר לקנות עוד בחנות', isError: true);
      return;
    }

    final used = await ref.read(playerProfileProvider.notifier).useHint();
    if (!used || !mounted) return;

    ref.read(soundServiceProvider).playHint();
    _boardKey.currentState?.showHint(word.path);
    _showBanner('💡 נסו את המילה: ${word.displayWord}');
  }

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    if (session == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess();
        _showBanner('${result.displayWord}  +${result.pointsAwarded}');
        setState(() {});
        if (session.isFullyCompleted) {
          Future.delayed(const Duration(milliseconds: 500), _finishLevel);
        }
        break;
      case WordSubmitStatus.duplicate:
        ref.read(soundServiceProvider).playError();
        _showBanner('כבר מצאת את "${result.displayWord}"', isError: true);
        _boardKey.currentState?.flashError();
        break;
      case WordSubmitStatus.invalidWord:
        ref.read(soundServiceProvider).playError();
        _showBanner('לא נמצאה מילה כזו', isError: true);
        _boardKey.currentState?.flashError();
        break;
      case WordSubmitStatus.tooShort:
      case WordSubmitStatus.invalidPath:
        _boardKey.currentState?.flashError();
        break;
    }
  }

  Future<void> _finishLevel() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final session = _session;
    if (session == null) return;

    final stars = session.currentStars;
    // אבן-דרך: השלב הראשון של עולם חדש (גודל לוח שגדל) שהושלם בהצלחה
    // (לפחות כוכב אחד) - מזכה בפרס נדיב ומפעיל חגיגה מורחבת במסך התוצאה.
    final isMilestone = _config.isMilestoneLevel && stars >= 1;
    const milestoneBonusCoins = 75;
    const milestoneBonusHints = 3;

    final coinsEarned =
        stars * 10 + session.foundWordsCount * 2 + (isMilestone ? milestoneBonusCoins : 0);

    await ref.read(playerProfileProvider.notifier).completeLevel(
          levelNumber: widget.levelNumber,
          stars: stars,
          score: session.score,
          coinsEarned: coinsEarned,
        );

    if (isMilestone) {
      await ref.read(playerProfileProvider.notifier).grantHints(milestoneBonusHints);
    }

    if (!mounted) return;

    final result = GameScreenResult(
      score: session.score,
      stars: stars,
      foundWordsCount: session.foundWordsCount,
      totalPossibleWords: session.totalPossibleWords,
      totalPossibleScore: session.totalPossibleScore,
      foundWordsDisplay: session.foundNormalizedWords
          .map((w) => HebrewTrie.toDisplayWord(w))
          .toList(),
      coinsEarned: coinsEarned,
      isMilestoneLevel: isMilestone,
      bonusCoins: isMilestone ? milestoneBonusCoins : 0,
      bonusHints: isMilestone ? milestoneBonusHints : 0,
      newTierTitle: isMilestone ? _config.tier.titleHe : null,
      newGridSize: isMilestone ? _config.gridSize : null,
    );

    context.pushReplacement('/level/${widget.levelNumber}/result', extra: result);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final worldIndex = _config.tier.index;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/campaign');
      },
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
                        onExit: () => context.go('/campaign'),
                        onHint: _useHint,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TimerBar(
                          progress: _remaining.inMilliseconds /
                              _config.timeLimit.inMilliseconds,
                          urgent: _remaining.inSeconds < (_config.timeLimit.inSeconds * 0.2),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                      child: GridBoard(
                                        key: _boardKey,
                                        letters: session.board.letters,
                                        onPathSubmitted: _onPathSubmitted,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_bannerText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _bannerIsError
                                        ? AppColors.error
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 10),
                                    ],
                                  ),
                                  child: Text(
                                    _bannerText!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: _bannerIsError
                                          ? Colors.white
                                          : AppColors.success,
                                    ),
                                  ),
                                ).animate(key: ValueKey(_bannerText)).fadeIn().moveY(
                                    begin: 10, end: 0, duration: 200.ms),
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
                          words: session.foundNormalizedWords
                              .map((w) => HebrewTrie.toDisplayWord(w))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GameHeader extends ConsumerWidget {
  final int levelNumber;
  final int score;
  final VoidCallback onExit;
  final VoidCallback onHint;

  const _GameHeader({
    required this.levelNumber,
    required this.score,
    required this.onExit,
    required this.onHint,
  });

  /// רמזים שמורים לחשבונות אמיתיים - לאורח/ת מציגים הזמנה להירשם במקום
  /// לצרוך רמז, כדי לא לתת לאורח/ת גישה ל"אפשרות רמזים" בכלל.
  void _showGuestHintPrompt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('רמזים שמורים למי שנרשם/ת'),
        content: const Text(
          'הרשמו בחינם עם Google, Apple, Facebook או מייל וקבלו רמזי מתנה '
          'מיד ובונוס יומי - בלי לאבד את ההתקדמות הנוכחית שלכם.',
        ),
        actions: [
          TextButton(onPressed: () => dialogContext.pop(), child: const Text('אחר כך')),
          FilledButton(
            onPressed: () {
              dialogContext.pop();
              context.push('/auth');
            },
            child: const Text('הרשמה'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Text(
            'שלב $levelNumber',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const Spacer(),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isGuest ? () => _showGuestHintPrompt(context) : onHint,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isGuest ? Icons.lock_outline_rounded : Icons.lightbulb_rounded,
                      color: isGuest ? Colors.black45 : AppColors.star,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(isGuest ? 'הרשמה' : '$hints',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$score נק׳', style: const TextStyle(fontWeight: FontWeight.w800)),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              child: const Text('הבנתי, בואו נתחיל!'),
            ),
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
