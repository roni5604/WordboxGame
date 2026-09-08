import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/bot_player.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/found_words_panel.dart';
import '../game/widgets/grid_board.dart';
import '../game/widgets/mascot_widget.dart';
import '../game/widgets/timer_bar.dart';
import 'models/race_config.dart';
import 'models/race_result.dart';
import 'widgets/live_scoreboard.dart';

class RaceGameScreen extends ConsumerStatefulWidget {
  final RaceConfig config;

  const RaceGameScreen({super.key, required this.config});

  @override
  ConsumerState<RaceGameScreen> createState() => _RaceGameScreenState();
}

class _RaceGameScreenState extends ConsumerState<RaceGameScreen> {
  GameSession? _session;
  List<BotPlayer> _bots = [];
  Duration _remaining = Duration.zero;
  Timer? _ticker;
  final _boardKey = GlobalKey<GridBoardState>();

  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.config.timeLimit;
    _initRace();
  }

  Future<void> _initRace() async {
    final dictionary = await ref.read(dictionaryLoadProvider.future);
    final weights = await ref.read(letterFrequencyProvider.future);

    final generator = BoardGenerator(trie: dictionary.trie, letterWeights: weights);
    final board = generator.generate(
      size: widget.config.gridSize,
      minWordsRequired: 6 + widget.config.gridSize,
    );

    final pseudoLevelConfig = LevelConfig(
      levelNumber: 0,
      tier: WorldTier.bloom,
      gridSize: widget.config.gridSize,
      timeLimit: widget.config.timeLimit,
      oneStarScore: 1,
      twoStarScore: 2,
      threeStarScore: 3,
    );

    final session = GameSession(config: pseudoLevelConfig, board: board, trie: dictionary.trie);
    final bots = widget.config.bots
        .map((b) => BotPlayer(name: b.name, difficulty: b.difficulty, board: board))
        .toList();

    if (!mounted) return;
    setState(() {
      _session = session;
      _bots = bots;
    });
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
            _showBanner('${bot.name} מצא/ה מילה! (${HebrewTrie.toDisplayWord(found.normalizedWord)})');
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

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    if (session == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess();
        _showBanner('${result.displayWord}  +${result.pointsAwarded}');
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

    final participants = <RaceParticipantResult>[
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

    context.pushReplacement('/multiplayer/race/result', extra: RaceResult(rankedParticipants: participants));
  }

  List<ScoreboardEntry> _buildScoreboard() {
    final session = _session;
    if (session == null) return [];
    final entries = <ScoreboardEntry>[
      ScoreboardEntry(name: widget.config.humanName, score: session.score, isHuman: true),
      for (final bot in _bots) ScoreboardEntry(name: bot.name, score: bot.score, isHuman: false),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
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
                            IconButton(
                              onPressed: () => context.go('/home'),
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                            const Text(
                              'תחרות מקומית',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${session.score} נק׳',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
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
                      const SizedBox(height: 12),
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _bannerIsError ? AppColors.error : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 10),
                                    ],
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
