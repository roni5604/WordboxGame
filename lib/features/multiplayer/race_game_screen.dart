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
import '../../game_engine/bot_player.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/current_word_badge.dart';
import '../game/widgets/found_words_panel.dart';
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

  @override
  void initState() {
    super.initState();
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
    final bots = widget.config.bots
        .map((b) => BotPlayer(name: b.name, difficulty: b.difficulty, board: board))
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

        for (final bot in _bots) {
          final found = bot.tick(tickDuration);
          if (found != null) {
            // לא חושפים איזו מילה הבוט מצא (זה היה "רמז" חינם) - רק הכרטיס
            // שלו בלוח התוצאות פועם עם +N.
            final gain = scoreForWordLength(found.normalizedWord.length);
            final prev = _gains[bot.name];
            _gains[bot.name] = ((prev?.$1 ?? 0) + 1, gain);
          }
        }

        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          _finishRace();
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
        ref.read(soundServiceProvider).playSuccess();
        _showBanner('${result.displayWord}  +${result.pointsAwarded}');
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
