import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/cosmetics/cosmetic_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/daily_challenge.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../../core/audio/music_service.dart';
import '../game/widgets/current_word_badge.dart';
import '../game/widgets/found_words_panel.dart';
import '../game/widgets/grid_board.dart';
import '../game/widgets/mascot_widget.dart';
import '../game/widgets/pause_menu.dart';
import '../game/widgets/timer_bar.dart';
import 'daily_challenge_screen.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/platform/browser_back_guard.dart';

/// משחק האתגר היומי: לוח אחד לכל העולם (מזרע התאריך), ספירה לאחור,
/// 90 שניות, וניסיון רשמי אחד. בסיום התוצאה נרשמת (ניקוד, רצף, מטבעות)
/// וחוזרים למסך האתגר עם החגיגה ודירוג החברים.
class DailyChallengeGameScreen extends ConsumerStatefulWidget {
  const DailyChallengeGameScreen({super.key});

  @override
  ConsumerState<DailyChallengeGameScreen> createState() => _DailyChallengeGameScreenState();
}

class _DailyChallengeGameScreenState extends ConsumerState<DailyChallengeGameScreen> with WidgetsBindingObserver {
  late final DailyChallenge _challenge = DailyChallenge.forDate(DateTime.now());
  final _boardKey = GlobalKey<GridBoardState>();
  GameSession? _session;
  Duration _remaining = Duration.zero;
  Timer? _ticker;
  bool _countingDown = false;
  bool _paused = false;
  bool _finished = false;
  String _draggingWord = '';
  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;

  // Analytics: daily_start when the clock starts, daily_end exactly once.
  // Plain singleton (not ref): also used from dispose().
  final AnalyticsService _analytics = AnalyticsService.instance;
  bool _dailyStarted = false;
  bool _dailyEnded = false;

  int get _playedSeconds =>
      (_challenge.timeLimit - _remaining).inSeconds.clamp(0, _challenge.timeLimit.inSeconds);

  void _logDailyEnd(String reason) {
    if (!_dailyStarted || _dailyEnded) return;
    _dailyEnded = true;
    final score = _session?.score ?? 0;
    _analytics.dailyEnd(
      dailyDate: _challenge.dateKey,
      // The daily has no pass/fail goal: success = finished with any score.
      success: score > 0,
      score: score,
      timeSec: _playedSeconds,
      wordsFound: _session?.foundWordsCount ?? 0,
      reason: reason,
    );
  }

  late final MusicService _music;

  @override
  void initState() {
    super.initState();
    // בזמן המשחק עצמו אין מוזיקת רקע - רק אפקטים.
    _music = ref.read(musicServiceProvider)..enterGame();
    _remaining = _challenge.timeLimit;
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final notifier = ref.read(playerProfileProvider.notifier);
    await notifier.forfeitAbandonedDaily(_challenge);
    final profile = await notifier.ensureLoaded();
    if (!mounted) return;
    // כבר שוחק היום (למשל חזרה בכפתור "אחורה" של הדפדפן, או ניסיון שננטש
    // באמצע) - חוזרים למסך האתגר.
    if (profile.playedDailyOn(_challenge.dateKey)) {
      context.go('/daily');
      return;
    }
    final dictionary = await ref.read(dictionaryLoadProvider.future);
    final weights = await ref.read(letterFrequencyProvider.future);
    final generator = BoardGenerator(trie: dictionary.trie, letterWeights: weights, random: Random(_challenge.seed));
    final board = generator.generate(size: _challenge.gridSize, minWordsRequired: 8 + _challenge.gridSize);
    final session = GameSession(
      config: LevelConfig(
        levelNumber: 0,
        tier: WorldTier.bloom,
        gridSize: _challenge.gridSize,
        timeLimit: _challenge.timeLimit,
        scoreRequired: CampaignLevels.raceScoreGoal,
      ),
      board: board,
      trie: dictionary.trie,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _countingDown = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _pause();
  }

  @override
  void dispose() {
    // Left mid-run (e.g. browser navigation): recorded as 0 next time.
    _logDailyEnd('abandon');
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _bannerTimer?.cancel();
    _music.leaveGame();
    super.dispose();
  }

  void _onCountdownDone() {
    if (!mounted) return;
    setState(() => _countingDown = false);
    ref.read(playerProfileProvider.notifier).markDailyStarted(_challenge);
    _dailyStarted = true;
    _analytics.dailyStart(dailyDate: _challenge.dateKey, gridSize: _challenge.gridSize);
    _startTimer();
  }

  void _startTimer() {
    const tick = Duration(milliseconds: 100);
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (timer) {
      if (!mounted) return;
      setState(() => _remaining -= tick);
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        timer.cancel();
        _finish();
      }
    });
  }

  /// השהיה מותרת (אין יריבים חיים) - אבל הלוח מוסתר כדי שלא "יחשבו" בזמן עצירה.
  Future<void> _pause() async {
    if (_paused || _finished || _session == null || _countingDown) return;
    _ticker?.cancel();
    _ticker = null;
    setState(() => _paused = true);
    final choice = await showPauseMenu(
      context,
      title: 'האתגר מושהה',
      subtitle: '${_session?.score ?? 0} נקודות · ${_remaining.inSeconds} שניות נותרו',
      canRestart: false,
      exitLabel: 'סיום עכשיו',
      exitWarning: 'יש ניסיון אחד ביום - סיום עכשיו יירשם עם הניקוד הנוכחי.',
    );
    if (!mounted) return;
    if (choice == PauseChoice.exit) {
      _finish(reason: 'quit');
    } else {
      setState(() => _paused = false);
      if (!_finished && _remaining > Duration.zero) _startTimer();
    }
  }

  Future<void> _finish({String reason = 'time_up'}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final session = _session;
    if (session == null) return;
    _logDailyEnd(reason);
    final outcome = await ref
        .read(playerProfileProvider.notifier)
        .recordDailyChallenge(challenge: _challenge, score: session.score, words: session.foundWordsCount);
    if (outcome != null) {
      _analytics.earnVirtualCurrency(currency: 'coins', value: outcome.coins, source: 'daily', item: 'daily_challenge');
    }
    if (!mounted) return;
    ref.read(soundServiceProvider).playLevelComplete();
    context.pushReplacement('/daily', extra: DailyChallengeArgs(outcome: outcome));
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

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    if (session == null || _finished) return;
    final result = session.submitPath(path);
    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess(letters: path.length);
        _showBanner(result.bannerText);
      case WordSubmitStatus.duplicate:
        ref.read(soundServiceProvider).playError();
        _showBanner('כבר מצאת את "${result.displayWord}"', isError: true);
        _boardKey.currentState?.flashError();
      case WordSubmitStatus.invalidWord:
        ref.read(soundServiceProvider).playError();
        _showBanner('לא נמצאה מילה כזו', isError: true);
        _boardKey.currentState?.flashError();
      case WordSubmitStatus.tooShort:
      case WordSubmitStatus.invalidPath:
        _boardKey.currentState?.flashError();
    }
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
          color: kDailyGradient.first,
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kDailyGradient),
              ),
              child: SafeArea(
                child: session == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MascotWidget(mood: MascotMood.excited, size: 100),
                            SizedBox(height: 16),
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('מכינים את האתגר של היום...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                CandyIconButton(
                                  icon: Icons.pause_rounded,
                                  tooltip: 'השהיה',
                                  size: 42,
                                  onPressed: _countingDown ? null : _pause,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'אתגר יומי #${_challenge.number}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const Text(
                                        'אותו לוח לכולם - ניסיון אחד',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                                  ),
                                  child: Text(
                                    '${session.score} נק׳',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ).animate(key: ValueKey(session.score)).scaleXY(begin: 1.2, end: 1, duration: 260.ms),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: TimerBar(
                              progress: _remaining.inMilliseconds / _challenge.timeLimit.inMilliseconds,
                              urgent: _remaining.inSeconds < 15,
                              secondsLeft: _remaining.inSeconds,
                            ),
                          ),
                          CurrentWordBadge(word: _draggingWord),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final side = min(constraints.maxWidth, constraints.maxHeight);
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
                                              onWordChanged: (w) {
                                                if (w != _draggingWord) setState(() => _draggingWord = w);
                                              },
                                              enabled: !_countingDown && !_paused && !_finished,
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: FoundWordsPanel(
                              words: session.foundNormalizedWords.map(HebrewTrie.toDisplayWord).toList(),
                            ),
                          ),
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

/// אישור לפני תחילת האתגר: יש רק ניסיון אחד ביום.
Future<bool> confirmStartDaily(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'מוכנים?',
    message: 'יש ניסיון אחד ביום, והתוצאה נרשמת בדירוג החברים. אפשר להשהות, אבל יציאה מסיימת את האתגר.',
    confirmLabel: 'יאללה!',
    cancelLabel: 'עוד רגע',
    confirmPalette: CandyPalette.green,
  );
}
