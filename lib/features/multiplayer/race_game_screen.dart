import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/cosmetics/cosmetic_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/bot_commentary.dart';
import '../../game_engine/bot_player.dart';
import '../../game_engine/dictionary/common_word_pool.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/common_word_pool_provider.dart';
import '../../core/ui/game_dialog.dart';
import '../profile/avatars/avatar_catalog.dart';
import 'widgets/bot_speech_bubble.dart';
import 'widgets/race_words_panel.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../../core/audio/music_service.dart';
import '../game/widgets/current_word_badge.dart';
import '../game/widgets/grid_board.dart';
import '../game/widgets/mascot_widget.dart';
import '../game/widgets/pause_menu.dart';
import '../game/widgets/timer_bar.dart';
import 'models/race_config.dart';
import 'models/race_result.dart';
import 'widgets/live_scoreboard.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/platform/browser_back_guard.dart';

class RaceGameScreen extends ConsumerStatefulWidget {
  final RaceConfig config;

  const RaceGameScreen({super.key, required this.config});

  @override
  ConsumerState<RaceGameScreen> createState() => _RaceGameScreenState();
}

class _RaceGameScreenState extends ConsumerState<RaceGameScreen> with WidgetsBindingObserver {
  /// ספירה לאחור "3, 2, 1" לפני שהשעון והבוטים מתחילים.
  bool _countingDown = false;
  bool _paused = false;

  GameSession? _session;
  List<BotPlayer> _bots = [];
  Duration _remaining = Duration.zero;
  Timer? _ticker;
  final _boardKey = GlobalKey<GridBoardState>();

  /// לכל משתתף/ת: (מונה אירועי ניקוד, נקודות באירוע האחרון) - לאנימציית
  /// "+N" בלוח התוצאות החי.
  final Map<String, (int, int)> _gains = {};

  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;
  bool _finished = false;

  /// המילה שנבנית כרגע תוך כדי גרירה על הלוח - ראו game_screen.dart
  /// להסבר המלא; מוצגת גם כאן כדי שהעיצוב יהיה עקבי בין כל מסכי המשחק.
  String _draggingWord = '';

  // Analytics: mp_match_start when the clock starts, mp_match_end once.
  // Plain singleton (not ref): also used from dispose().
  final AnalyticsService _analytics = AnalyticsService.instance;
  bool _matchStarted = false;
  bool _matchEnded = false;

  /// הערות הבוטים - מעט, בזמן הנכון (ראו BotCommentary).
  final BotCommentary _commentary = BotCommentary();
  BotComment? _comment;
  int _commentSerial = 0;
  Timer? _commentTimer;
  Duration _humanIdle = Duration.zero;
  int _tickCount = 0;

  /// "הצצה" למילים של היריבים - נקנית פעם אחת לתחרות.
  bool _spyUnlocked = false;

  Duration get _elapsed => widget.config.timeLimit - _remaining;

  int get _playedSeconds =>
      (widget.config.timeLimit - _remaining).inSeconds.clamp(0, widget.config.timeLimit.inSeconds);

  void _logMatchEnd(String result) {
    if (!_matchStarted || _matchEnded) return;
    _matchEnded = true;
    _analytics.mpMatchEnd(
      mode: 'bots',
      players: widget.config.totalPlayers,
      result: result,
      score: _session?.score ?? 0,
      durationSec: _playedSeconds,
    );
  }

  late final MusicService _music;

  @override
  void initState() {
    super.initState();
    // בזמן המשחק עצמו אין מוזיקת רקע - רק אפקטים.
    _music = ref.read(musicServiceProvider)..enterGame();
    _remaining = widget.config.timeLimit;
    WidgetsBinding.instance.addObserver(this);
    _initRace();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _pause();
  }

  /// השהיה (כפתור, "חזרה" של המערכת, או יציאה מהאפליקציה): השעון והבוטים
  /// נעצרים והלוח מוסתר - אף אחד לא "מרוויח" זמן.
  Future<void> _pause() async {
    if (_paused || _finished || _session == null || _countingDown) return;
    _ticker?.cancel();
    _ticker = null;
    setState(() => _paused = true);
    final choice = await showPauseMenu(
      context,
      title: 'התחרות מושהית',
      subtitle: '${_session?.score ?? 0} נקודות · ${_remaining.inSeconds} שניות נותרו',
      exitLabel: 'יציאה לתפריט הראשי',
      exitWarning: 'יציאה עכשיו תסיים את התחרות בלי תוצאה.',
    );
    if (!mounted) return;
    switch (choice) {
      case PauseChoice.resume:
        setState(() => _paused = false);
        if (!_finished && _remaining > Duration.zero) _startTimer();
      case PauseChoice.restart:
        _finished = true;
        _logMatchEnd('abandon');
        context.pushReplacement('/multiplayer/race', extra: widget.config);
      case PauseChoice.exit:
        _finished = true;
        _logMatchEnd('abandon');
        context.go('/home');
    }
  }

  Future<void> _initRace() async {
    final dictionary = await ref.read(dictionaryLoadProvider.future);
    final weights = await ref.read(letterFrequencyProvider.future);

    final generator = BoardGenerator(trie: dictionary.trie, letterWeights: weights);
    final board = generator.generate(size: widget.config.gridSize, minWordsRequired: 6 + widget.config.gridSize);

    final pseudoLevelConfig = LevelConfig(
      levelNumber: 0,
      tier: WorldTier.bloom,
      gridSize: widget.config.gridSize,
      timeLimit: widget.config.timeLimit,
      // תחרות רב-משתתפים נגמרת לפי שעון, לא לפי יעד השלב.
      scoreRequired: CampaignLevels.raceScoreGoal,
    );

    final session = GameSession(config: pseudoLevelConfig, board: board, trie: dictionary.trie);
    // מילים "מוכרות" נמצאות קודם - כמו אצל שחקן/ית אמיתי/ת.
    CommonWordPool? pool;
    try {
      pool = await ref.read(commonWordPoolProvider.future);
    } catch (_) {}
    final bots = widget.config.bots
        .map((b) => BotPlayer(
              name: b.name,
              difficulty: b.difficulty,
              board: board,
              isFamiliar: pool?.isCommon,
            ))
        .toList();

    if (!mounted) return;
    setState(() {
      _session = session;
      _bots = bots;
      _countingDown = true;
    });
  }

  void _onCountdownDone() {
    if (!mounted) return;
    setState(() => _countingDown = false);
    if (!_matchStarted) {
      _matchStarted = true;
      _analytics.mpMatchStart(mode: 'bots', players: widget.config.totalPlayers, gridSize: widget.config.gridSize);
    }
    _startTimer();
  }

  void _startTimer() {
    const tickDuration = Duration(milliseconds: 100);
    _ticker = Timer.periodic(tickDuration, (timer) {
      if (!mounted) return;
      setState(() {
        _remaining -= tickDuration;
        _humanIdle += tickDuration;
        final humanScore = _session?.score ?? 0;

        for (final bot in _bots) {
          final found = bot.tick(tickDuration, humanScore: humanScore);
          if (found != null) {
            // בלי "הצצה" לא חושפים איזו מילה הבוט מצא - רק הכרטיס שלו פועם
            // עם +N. עם הצצה המילה נוחתת בלשונית שלו בלוח המילים.
            final gain = scoreForWord(found.normalizedWord);
            final prev = _gains[bot.name];
            _gains[bot.name] = ((prev?.$1 ?? 0) + 1, gain);
            _speak(_commentary.onBotWord(_elapsed, bot: bot.name, letters: found.normalizedWord.length));
          }
        }

        // פעם בשנייה: עקיפות, שקט, 20 שניות אחרונות.
        if (++_tickCount % 10 == 0) {
          final stuck = _bots.where((b) => b.isThinkingHard).map((b) => b.name).firstOrNull;
          _speak(_commentary.onTick(
            _elapsed,
            remaining: _remaining,
            humanScore: humanScore,
            botScores: {for (final b in _bots) b.name: b.score},
            humanIdle: _humanIdle,
            stuckBot: stuck,
          ));
        }

        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          _finishRace();
        }
      });
    });
  }

  void _speak(BotComment? comment) {
    if (comment == null || !mounted) return;
    _commentTimer?.cancel();
    setState(() {
      _comment = comment;
      _commentSerial++;
    });
    _commentTimer = Timer(BotSpeechBubble.visibleFor, () {
      if (mounted) setState(() => _comment = null);
    });
  }

  /// קניית "הצצה": השעון והבוטים נעצרים בזמן ההחלטה.
  Future<void> _unlockSpy() async {
    if (_spyUnlocked || _finished || _countingDown) return;
    final wasRunning = _ticker != null;
    _ticker?.cancel();
    _ticker = null;
    final coins = ref.read(playerProfileProvider).valueOrNull?.coins ?? 0;
    final yes = await showConfirmDialog(
      context,
      title: 'הצצה ליריבים 👀',
      message: 'לראות את כל המילים שהיריבים מוצאים בתחרות הזו - בזמן אמת.\nיש לך $coins מטבעות.',
      confirmLabel: '$kSpyCost מטבעות',
      cancelLabel: 'לא עכשיו',
      confirmPalette: CandyPalette.gold,
      hero: const Icon(Icons.visibility_rounded, size: 56, color: Color(0xFF7B3FF2)),
    );
    if (!mounted) return;
    if (yes) {
      final ok = await ref.read(playerProfileProvider.notifier).spendCoins(kSpyCost);
      if (!mounted) return;
      if (ok) {
        ref.read(soundServiceProvider).playCoin();
        _analytics.spendVirtualCurrency(currency: 'coins', value: kSpyCost, itemName: 'race_spy');
        setState(() => _spyUnlocked = true);
      } else {
        ref.read(soundServiceProvider).playError();
        GameToast.show(context,
            message: 'אין מספיק מטבעות להצצה', icon: Icons.paid_rounded, color: AppColors.error, duration: const Duration(milliseconds: 1600));
      }
    }
    if (wasRunning && !_finished && !_paused && _remaining > Duration.zero) _startTimer();
  }

  void _showBanner(String text, {bool isError = false}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerText = text;
      _bannerIsError = isError;
    });
    _bannerTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  void _onWordChanging(String word) {
    if (_draggingWord == word) return;
    setState(() => _draggingWord = word);
  }

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    if (session == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess(letters: path.length);
        _showBanner(result.bannerText);
        _humanIdle = Duration.zero;
        _speak(_commentary.onHumanWord(
          _elapsed,
          letters: path.length,
          displayWord: result.displayWord ?? '',
          bots: [for (final b in _bots) b.name],
        ));
        final prev = _gains['\u0000me'];
        _gains['\u0000me'] = ((prev?.$1 ?? 0) + 1, result.pointsAwarded);
        setState(() {});
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

  void _finishRace() {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();

    final session = _session;
    if (session == null) return;

    final participants =
        <RaceParticipantResult>[
          RaceParticipantResult(
            name: widget.config.humanName,
            score: session.score,
            wordsFound: session.foundWordsCount,
            isHuman: true,
          ),
          for (final bot in _bots)
            RaceParticipantResult(
              name: bot.name,
              score: bot.score,
              wordsFound: bot.foundNormalizedWords.length,
              isHuman: false,
            ),
        ]..sort((a, b) {
          final scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return b.wordsFound.compareTo(a.wordsFound);
        });

    // Same ranking the result screen shows (score, then words found); a draw
    // is a tie with the top score and word count.
    final top = participants.first;
    final tiedTop = participants.where((p) => p.score == top.score && p.wordsFound == top.wordsFound);
    final me = participants.firstWhere((p) => p.isHuman);
    final String result;
    if (!tiedTop.contains(me)) {
      result = 'lose';
    } else {
      result = tiedTop.length > 1 ? 'draw' : 'win';
    }
    _logMatchEnd(result);

    context.pushReplacement(
      '/multiplayer/race/result',
      extra: RaceResult(rankedParticipants: participants, config: widget.config),
    );
  }

  List<ScoreboardEntry> _buildScoreboard() {
    final session = _session;
    if (session == null) return [];
    // תמונת/שם הפרופיל האמיתי של השחקן/ית - מוצגים במקום קמע גנרי (ראו
    // live_scoreboard.dart), כדי שגם בדו-קרב מול המחשב יהיה ברור "מי אני".
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final entries = <ScoreboardEntry>[
      ScoreboardEntry(
        name: widget.config.humanName,
        score: session.score,
        isHuman: true,
        avatarId: profile?.avatarId ?? 'detective',
        photoUrl: authUser?.photoUrl,
        isMe: true,
        gainToken: _gains['\u0000me']?.$1 ?? 0,
        lastGain: _gains['\u0000me']?.$2 ?? 0,
      ),
      for (final bot in _bots)
        ScoreboardEntry(
          name: bot.name,
          score: bot.score,
          isHuman: false,
          avatarId: botAvatarId(bot.name),
          gainToken: _gains[bot.name]?.$1 ?? 0,
          lastGain: _gains[bot.name]?.$2 ?? 0,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  @override
  void dispose() {
    _logMatchEnd('abandon');
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _bannerTimer?.cancel();
    _commentTimer?.cancel();
    _music.leaveGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final boardSkin = CosmeticCatalog.boardById(profile?.boardSkinId);
    final letterSkin = CosmeticCatalog.letterById(profile?.letterSkinId);
    final markerSkin = CosmeticCatalog.markerById(profile?.markerSkinId);

    return BrowserBackGuard(
      onBlocked: _pause,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _pause();
        },
        child: TopBarTint(
          color: const Color(0xFF6A11CB),
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
              ),
              child: SafeArea(
                child: session == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MascotWidget(mood: MascotMood.idle, size: 100),
                            SizedBox(height: 16),
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('בונים זירת תחרות...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                CandyIconButton(
                                  icon: Icons.pause_rounded,
                                  tooltip: 'השהיה',
                                  size: 42,
                                  onPressed: _countingDown ? null : _pause,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'תחרות מקומית',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${session.score} נק׳',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: LiveScoreboard(entries: _buildScoreboard()),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TimerBar(
                              progress: _remaining.inMilliseconds / widget.config.timeLimit.inMilliseconds,
                              urgent: _remaining.inSeconds < (widget.config.timeLimit.inSeconds * 0.2),
                            ),
                          ),
                          // הערות היריבים "צפות" מתחת לשעון, מעל הלוח - בלי לדחוף את הפריסה
                          // ובלי לכסות אותיות (גובה 0, ציור מחוץ לגבולות).
                          SizedBox(
                            height: 0,
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: 90,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                                child: Align(
                                  alignment: AlignmentDirectional.topStart,
                                  child: _comment == null
                                      ? const SizedBox.shrink()
                                      : BotSpeechBubble(
                                          key: ValueKey('comment-$_commentSerial'),
                                          comment: _comment!,
                                          avatarId: botAvatarId(_comment!.botName),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                      final side = constraints.maxWidth < constraints.maxHeight
                                          ? constraints.maxWidth
                                          : constraints.maxHeight;
                                      return Center(
                                        child: SizedBox(
                                          width: side,
                                          height: side,
                                          child: PausableBoard(
                                            paused: _paused || _countingDown,
                                            child: GridBoard(
                                              key: _boardKey,
                                              letters: session.board.letters,
                                              onPathSubmitted: _onPathSubmitted,
                                              isPathAcceptable: session.wouldAccept,
                                              onWordChanged: _onWordChanging,
                                              enabled: !_countingDown && !_paused,
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
                                if (_countingDown) Positioned.fill(child: StartCountdown(onDone: _onCountdownDone)),
                                if (_bannerText != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _bannerIsError ? AppColors.error : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                                      ),
                                      child: Text(
                                        _bannerText!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _bannerIsError ? Colors.white : AppColors.success,
                                        ),
                                      ),
                                    ).animate(key: ValueKey(_bannerText)).fadeIn().moveY(begin: 10, end: 0),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: RaceWordsPanel(
                              mine: RaceWordList(
                                name: widget.config.humanName,
                                avatarId: profile?.avatarId ?? 'detective',
                                words: session.foundNormalizedWords.map((w) => HebrewTrie.toDisplayWord(w)).toList(),
                                isMe: true,
                              ),
                              opponents: [
                                for (final bot in _bots)
                                  RaceWordList(
                                    name: bot.name,
                                    avatarId: botAvatarId(bot.name),
                                    words: [for (final w in bot.foundWords) w.displayWord],
                                  ),
                              ],
                              unlocked: _spyUnlocked,
                              onUnlock: _unlockSpy,
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
