import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/found_words_panel.dart';
import '../game/widgets/grid_board.dart';
import '../game/widgets/mascot_widget.dart';
import '../game/widgets/timer_bar.dart';
import 'models/race_result.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';
import 'widgets/live_scoreboard.dart';

/// מסך המשחק במצב "משחק מול חברים" - זהה למבנה של [RaceGameScreen] (הלוח,
/// הטיימר, לוח התוצאות החי) אך במקום בוטים מקומיים, כל השחקנים הם
/// שחקנים אמיתיים המסונכרנים דרך Firestore: לוח זהה נוצר אצל כולם דרך
/// [GameRoom.boardSeed], הטיימר מסונכרן לפי [GameRoom.startedAt], וכל
/// שחקן/ית כותב/ת רק את הניקוד העצמי שלו/ה (ראו multiplayer_repository.dart).
///
/// לא נוגעים ב-RaceGameScreen הקיים (משחק מול המחשב) בכלל - זה מסך נפרד
/// שמרכיב מחדש את אותם רכיבי UI ציבוריים.
class OnlineRaceScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const OnlineRaceScreen({super.key, required this.roomCode});

  @override
  ConsumerState<OnlineRaceScreen> createState() => _OnlineRaceScreenState();
}

class _OnlineRaceScreenState extends ConsumerState<OnlineRaceScreen> {
  late final MultiplayerRepository _repo;
  StreamSubscription<GameRoom>? _roomSub;
  Timer? _ticker;
  final _boardKey = GlobalKey<GridBoardState>();

  String? _myUid;
  GameRoom? _room;
  GameSession? _session;
  Duration _remaining = Duration.zero;
  bool _initializingGame = false;
  bool _finished = false;

  String? _bannerText;
  bool _bannerIsError = false;
  Timer? _bannerTimer;

  // מעקב אחר הניקוד האחרון שנצפה לכל יריב/ה, כדי לזהות "עלייה" בניקוד
  // ולהציג עליה התראה חיה - בלי לחשוף איזו מילה בדיוק נמצאה (ראו
  // _notifyOpponentScoreChanges).
  final Map<String, int> _lastSeenOpponentScores = {};

  @override
  void initState() {
    super.initState();
    _repo = ref.read(multiplayerRepositoryProvider);
    _repo.ensureSignedIn().then((uid) {
      if (mounted) setState(() => _myUid = uid);
    });
    _roomSub = _repo.watchRoom(widget.roomCode).listen(_onRoomUpdate, onError: (_) {});
  }

  void _onRoomUpdate(GameRoom room) {
    _notifyOpponentScoreChanges(room);
    setState(() => _room = room);

    if (_session == null && !_initializingGame && room.startedAt != null) {
      _initializingGame = true;
      _initGame(room);
    }

    if (room.status == RoomStatus.finished && !_finished) {
      _finish();
    }
  }

  /// מציג הודעה קצרה בכל פעם שליריב/ה חדשות נקודות - "כמה" בלבד, בלי
  /// לחשוף איזו מילה נמצאה (כדי לא "לתת רמז" למילים שעדיין לא נמצאו).
  void _notifyOpponentScoreChanges(GameRoom room) {
    for (final player in room.players) {
      if (player.uid == _myUid) continue;
      final previousScore = _lastSeenOpponentScores[player.uid];
      _lastSeenOpponentScores[player.uid] = player.score;
      if (previousScore == null) continue; // תפיסה ראשונית - לא "עלייה" אמיתית.

      final delta = player.score - previousScore;
      if (delta > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 ${player.displayName} הרוויח/ה +$delta נק׳!'),
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _initGame(GameRoom room) async {
    final dictionary = await ref.read(dictionaryLoadProvider.future);
    final weights = await ref.read(letterFrequencyProvider.future);

    final generator = BoardGenerator(
      trie: dictionary.trie,
      letterWeights: weights,
      random: Random(room.boardSeed),
    );
    final board = generator.generate(
      size: room.gridSize,
      minWordsRequired: 6 + room.gridSize,
    );

    final pseudoLevelConfig = LevelConfig(
      levelNumber: 0,
      tier: WorldTier.bloom,
      gridSize: room.gridSize,
      timeLimit: Duration(seconds: room.roundSeconds),
      // משחק מול חברים לא משתמש בכוכבים/יעד-מילים - רק בניקוד גולמי.
      wordsRequired: 1,
    );

    final session = GameSession(config: pseudoLevelConfig, board: board, trie: dictionary.trie);

    if (!mounted) return;
    setState(() => _session = session);
    _startTicker(room);
  }

  void _startTicker(GameRoom room) {
    final startedAt = room.startedAt;
    if (startedAt == null) return;

    void tick() {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = Duration(seconds: room.roundSeconds) - elapsed;
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
      if (_remaining <= Duration.zero) {
        _ticker?.cancel();
        _finish();
      }
    }

    tick();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
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
    final room = _room;
    if (session == null || room == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess();
        _showBanner('${result.displayWord}  +${result.pointsAwarded}');
        setState(() {});
        _repo
            .updateMyScore(widget.roomCode, score: session.score, wordsFound: session.foundWordsCount)
            .catchError((_) {});
        if (room.hasTargetScore && session.score >= room.targetScore) {
          _finish();
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

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();

    final session = _session;
    final room = _room;
    if (session == null || room == null) {
      _repo.finishRoom(widget.roomCode).catchError((_) {});
      return;
    }

    final ranked = <({String uid, RaceParticipantResult result})>[
      for (final player in room.players)
        (
          uid: player.uid,
          result: RaceParticipantResult(
            name: player.displayName,
            score: player.uid == _myUid ? session.score : player.score,
            wordsFound: player.uid == _myUid ? session.foundWordsCount : player.wordsFound,
            isHuman: player.uid == _myUid,
          ),
        ),
    ]..sort((a, b) {
        final scoreCompare = b.result.score.compareTo(a.result.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.result.wordsFound.compareTo(a.result.wordsFound);
      });

    // מעניקים ניצחון רק כשיש מוביל/ה יחיד/ה בלי שוויון - כדי שהיחס
    // (1:2 וכו') ב-OnlineRaceResultScreen יהיה משמעותי.
    String? winnerUid;
    if (ranked.length == 1) {
      winnerUid = ranked.first.uid;
    } else if (ranked.length >= 2 && ranked[0].result.score != ranked[1].result.score) {
      winnerUid = ranked.first.uid;
    }
    _repo.finishRoom(widget.roomCode, winnerUid: winnerUid).catchError((_) {});

    if (!mounted) return;
    final participants = [for (final entry in ranked) entry.result];
    context.pushReplacement(
      '/multiplayer/online/room/${widget.roomCode}/result',
      extra: RaceResult(rankedParticipants: participants),
    );
  }

  Future<void> _exitToHome() async {
    try {
      await _repo.leaveRoom(widget.roomCode);
    } catch (_) {
      // עזיבה טובה-מאמץ.
    }
    if (mounted) context.go('/home');
  }

  List<ScoreboardEntry> _buildScoreboard() {
    final session = _session;
    final room = _room;
    if (session == null || room == null) return [];
    final entries = <ScoreboardEntry>[
      for (final player in room.players)
        ScoreboardEntry(
          name: player.uid == _myUid ? '${player.displayName} (את/ה)' : player.displayName,
          score: player.uid == _myUid ? session.score : player.score,
          isHuman: player.uid == _myUid,
          isMe: player.uid == _myUid,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  @override
  void dispose() {
    _roomSub?.cancel();
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
        if (!didPop) _exitToHome();
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
                        Text('ממתינים שהמשחק יתחיל...', style: TextStyle(color: Colors.white)),
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
                              onPressed: _exitToHome,
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                            const Text(
                              'משחק מול חברים',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.accent, width: 2),
                                boxShadow: [
                                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 10),
                                ],
                              ),
                              child: Text('${session.score} נק׳',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accent)),
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
                          progress: _room == null
                              ? 0
                              : _remaining.inMilliseconds / (Duration(seconds: _room!.roundSeconds).inMilliseconds),
                          urgent: _room != null && _remaining.inSeconds < (_room!.roundSeconds * 0.2),
                          secondsLeft: _remaining.inSeconds,
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
