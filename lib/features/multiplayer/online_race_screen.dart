import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/cosmetics/cosmetic_catalog.dart' hide CoinCosts;
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../game_engine/board_generator.dart';
import '../../game_engine/dictionary/hebrew_trie.dart';
import '../../game_engine/game_session.dart';
import '../../game_engine/models/grid_position.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/letter_frequency_provider.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../../core/audio/music_service.dart';
import '../game/widgets/current_word_badge.dart';
import '../game/widgets/secret_word_card.dart';
import '../game/widgets/grid_board.dart';
import '../game/widgets/mascot_widget.dart';
import '../game/widgets/timer_bar.dart';
import 'models/race_result.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';
import 'widgets/live_scoreboard.dart';
import 'widgets/race_words_panel.dart';
import '../../core/cosmetics/cosmetic_catalog.dart' show CoinCosts;
import '../../core/feedback/haptics.dart';
import '../../game_engine/word_finder.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/platform/browser_back_guard.dart';

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

  /// המילה שנבנית כרגע תוך כדי גרירה על הלוח - ראו game_screen.dart
  /// להסבר המלא; מוצגת גם כאן כדי שהעיצוב יהיה עקבי בין כל מסכי המשחק.
  String _draggingWord = '';

  // מעקב אחר הניקוד האחרון שנצפה לכל יריב/ה, כדי לזהות "עלייה" בניקוד
  // ולהציג עליה התראה חיה - בלי לחשוף איזו מילה בדיוק נמצאה (ראו
  // _notifyOpponentScoreChanges).
  final Map<String, int> _lastSeenOpponentScores = {};

  /// לכל שחקן/ית: (מונה אירועי ניקוד, נקודות באירוע האחרון) - לאנימציית
  /// "+N" בלוח התוצאות החי.
  final Map<String, (int, int)> _gains = {};

  /// "הצצה" למילים של החברים (נקנית פעם אחת לסבב) ו"גלה מילה".
  bool _spyUnlocked = false;
  FoundWord? _secretWord;
  bool _secretFound = false;
  Timer? _secretTimer;

  // Analytics: mp_match_start when the round starts locally, mp_match_end once.
  // Plain singleton (not ref): also used from dispose().
  final AnalyticsService _analytics = AnalyticsService.instance;
  DateTime? _matchStartedAt;
  int _matchPlayers = 0;
  bool _matchEnded = false;

  void _logMatchEnd(String result) {
    final startedAt = _matchStartedAt;
    if (startedAt == null || _matchEnded) return;
    _matchEnded = true;
    final roundSeconds = _room?.roundSeconds;
    var duration = DateTime.now().difference(startedAt).inSeconds;
    if (roundSeconds != null && duration > roundSeconds) duration = roundSeconds;
    _analytics.mpMatchEnd(
      mode: 'friends',
      players: _matchPlayers,
      result: result,
      score: _session?.score ?? 0,
      durationSec: duration < 0 ? 0 : duration,
    );
  }

  late final MusicService _music;

  @override
  void initState() {
    super.initState();
    // בזמן המשחק עצמו אין מוזיקת רקע - רק אפקטים.
    _music = ref.read(musicServiceProvider)..enterGame();
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
      if (delta > 0) {
        // בלי לחשוף איזו מילה נמצאה: רק הכרטיס של היריב/ה פועם עם +N.
        final prev = _gains[player.uid];
        _gains[player.uid] = ((prev?.$1 ?? 0) + 1, delta);
      }
    }
  }

  Future<void> _initGame(GameRoom room) async {
    final dictionary = await ref.read(dictionaryLoadProvider.future);
    final weights = await ref.read(letterFrequencyProvider.future);

    final generator = BoardGenerator(trie: dictionary.trie, letterWeights: weights, random: Random(room.boardSeed));
    final board = generator.generate(size: room.gridSize, minWordsRequired: 6 + room.gridSize);

    final pseudoLevelConfig = LevelConfig(
      levelNumber: 0,
      tier: WorldTier.bloom,
      gridSize: room.gridSize,
      timeLimit: Duration(seconds: room.roundSeconds),
      // משחק מול חברים נגמר לפי שעון, לא לפי יעד השלב.
      scoreRequired: CampaignLevels.raceScoreGoal,
    );

    final session = GameSession(config: pseudoLevelConfig, board: board, trie: dictionary.trie);

    if (!mounted) return;
    setState(() => _session = session);
    ref.read(soundServiceProvider).playLevelStart();
    _matchStartedAt = DateTime.now();
    _matchPlayers = room.players.length;
    _analytics.mpMatchStart(mode: 'friends', players: _matchPlayers, gridSize: room.gridSize);
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

  bool get _isGuest {
    final user = ref.read(authStateProvider).valueOrNull;
    return user == null || user.isAnonymous;
  }

  /// 💡 רמז: מדגיש על הלוח מילה שעוד לא מצאתי (עולה רמז אחד).
  Future<void> _useHint() async {
    final session = _session;
    if (session == null || _finished) return;
    if (_isGuest) {
      _showBanner('רמזים שמורים לחשבונות רשומים', isError: true);
      return;
    }
    final word = session.hintForUnfoundWord();
    if (word == null) {
      _showBanner('כבר מצאת את כל המילים! 🎉');
      return;
    }
    final used = await ref.read(playerProfileProvider.notifier).useHint();
    if (!mounted) return;
    if (!used) {
      ref.read(soundServiceProvider).playError();
      _showBanner('נגמרו הרמזים - אפשר לקנות בחנות', isError: true);
      return;
    }
    _analytics
      ..spendVirtualCurrency(currency: 'hints', value: 1, itemName: 'word_hint')
      ..hintUsed(levelId: 0, hintType: 'word_hint', cost: 1, costCurrency: 'hints');
    ref.read(soundServiceProvider).playHint();
    _boardKey.currentState?.showHint(word.path);
    _showBanner('💡 נסו את המילה: ${word.displayWord}');
  }

  /// 🔎 גלה מילה: מילה סודית מעל הלוח עד שמוצאים אותה (במטבעות).
  Future<void> _revealWord() async {
    final session = _session;
    if (session == null || _finished) return;
    final current = _secretWord;
    if (current != null && !_secretFound) {
      _showBanner('קודם מצאו את "${current.displayWord}" 🔎');
      return;
    }
    final word = session.revealWordCandidate();
    if (word == null) {
      _showBanner('כבר מצאת את כל המילים! 🎉');
      return;
    }
    final ok = await ref.read(playerProfileProvider.notifier).spendCoins(CoinCosts.revealWord);
    if (!mounted) return;
    if (!ok) {
      ref.read(soundServiceProvider).playError();
      _showBanner('אין מספיק מטבעות (${CoinCosts.revealWord})', isError: true);
      return;
    }
    _analytics
      ..spendVirtualCurrency(currency: 'coins', value: CoinCosts.revealWord, itemName: 'reveal_word')
      ..hintUsed(levelId: 0, hintType: 'reveal_word', cost: CoinCosts.revealWord, costCurrency: 'coins');
    ref.read(soundServiceProvider).playHint();
    Haptics.medium();
    _secretTimer?.cancel();
    setState(() {
      _secretWord = word;
      _secretFound = false;
    });
  }

  void _checkSecretFound() {
    final session = _session;
    final secret = _secretWord;
    if (session == null || secret == null || _secretFound || !session.isFound(secret.normalizedWord)) return;
    setState(() => _secretFound = true);
    _secretTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _secretWord = null);
    });
  }

  /// "הצצה" למילים של החברים - משחק חי, אז בלי דיאלוג (האישור בלשונית).
  Future<void> _unlockSpy() async {
    if (_spyUnlocked || _finished) return;
    final ok = await ref.read(playerProfileProvider.notifier).spendCoins(kSpyCost);
    if (!mounted) return;
    if (!ok) {
      ref.read(soundServiceProvider).playError();
      _showBanner('אין מספיק מטבעות להצצה ($kSpyCost)', isError: true);
      return;
    }
    ref.read(soundServiceProvider).playCoin();
    _analytics.spendVirtualCurrency(currency: 'coins', value: kSpyCost, itemName: 'friends_spy');
    setState(() => _spyUnlocked = true);
  }

  void _onWordChanging(String word) {
    if (_draggingWord == word) return;
    setState(() => _draggingWord = word);
  }

  void _onPathSubmitted(List<GridPosition> path) {
    final session = _session;
    final room = _room;
    if (session == null || room == null || _finished) return;
    final result = session.submitPath(path);

    switch (result.status) {
      case WordSubmitStatus.accepted:
        ref.read(soundServiceProvider).playSuccess(letters: path.length);
        _showBanner(result.bannerText);
        if (_myUid != null) {
          final prev = _gains[_myUid!];
          _gains[_myUid!] = ((prev?.$1 ?? 0) + 1, result.pointsAwarded);
        }
        setState(() {});
        _checkSecretFound();
        _repo
            .updateMyScore(
              widget.roomCode,
              score: session.score,
              wordsFound: session.foundWordsCount,
              words: [for (final w in session.foundNormalizedWords) HebrewTrie.toDisplayWord(w)],
            )
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

    final ranked =
        <({String uid, RaceParticipantResult result})>[
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

    final String matchResult;
    if (winnerUid != null) {
      matchResult = winnerUid == _myUid ? 'win' : 'lose';
    } else {
      final topScore = ranked.isEmpty ? 0 : ranked.first.result.score;
      final mine = ranked.where((e) => e.uid == _myUid);
      matchResult = mine.isNotEmpty && mine.first.result.score == topScore ? 'draw' : 'lose';
    }
    _logMatchEnd(matchResult);

    if (!mounted) return;
    final participants = [for (final entry in ranked) entry.result];
    context.pushReplacement(
      '/multiplayer/online/room/${widget.roomCode}/result',
      extra: RaceResult(rankedParticipants: participants),
    );
  }

  /// משחק חי מול אנשים אמיתיים לא אפשר להשהות - לכן "חזרה"/X שואלים
  /// לפני שיוצאים, כדי שתנועה בטעות לא תוציא מהסבב.
  Future<void> _confirmExit() async {
    final ok = await showConfirmDialog(
      context,
      title: 'לצאת מהמשחק?',
      message: 'המשחק ממשיך בלעדיך, והניקוד שלך ייעצר כאן.',
      confirmLabel: 'יציאה',
      cancelLabel: 'נשארים לשחק',
      confirmPalette: CandyPalette.red,
    );
    if (ok && mounted) await _exitToHome();
  }

  Future<void> _exitToHome() async {
    _logMatchEnd('abandon');
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
    // תמונת/שם הפרופיל האמיתי שלי - מוצגים במקום קמע גנרי (ראו
    // live_scoreboard.dart), רק לשורה של עצמי; לשאר השחקנים/ות בחדר
    // הפרטי אין עדיין תמונת פרופיל שמורה בצד השרת.
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final entries = <ScoreboardEntry>[
      for (final player in room.players)
        ScoreboardEntry(
          name: player.uid == _myUid ? '${player.displayName} (את/ה)' : player.displayName,
          score: player.uid == _myUid ? session.score : player.score,
          isHuman: true,
          isMe: player.uid == _myUid,
          avatarId: player.uid == _myUid ? (profile?.avatarId ?? 'detective') : (player.avatarId ?? 'detective'),
          photoUrl: player.uid == _myUid ? authUser?.photoUrl : player.photoUrl,
          wins: room.isSeries ? (room.wins[player.uid] ?? 0) : null,
          gainToken: _gains[player.uid]?.$1 ?? 0,
          lastGain: _gains[player.uid]?.$2 ?? 0,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  @override
  void dispose() {
    _logMatchEnd('abandon');
    _roomSub?.cancel();
    _ticker?.cancel();
    _bannerTimer?.cancel();
    _secretTimer?.cancel();
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
      onBlocked: _confirmExit,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmExit();
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
                                CandyIconButton(
                                  icon: Icons.close_rounded,
                                  tooltip: 'יציאה',
                                  size: 42,
                                  onPressed: _confirmExit,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'משחק מול חברים',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                      if (_room != null && _room!.isSeries)
                                        Text(
                                          _room!.roundLabel,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
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
                                  child: Text(
                                    '${session.score} נק׳',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppColors.accent,
                                    ),
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
                              progress: _room == null
                                  ? 0
                                  : _remaining.inMilliseconds / (Duration(seconds: _room!.roundSeconds).inMilliseconds),
                              urgent: _room != null && _remaining.inSeconds < (_room!.roundSeconds * 0.2),
                              secondsLeft: _remaining.inSeconds,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _HelperRow(onHint: _useHint, onReveal: _revealWord),
                          ),
                          const SizedBox(height: 4),
                          CurrentWordBadge(word: _draggingWord),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutBack,
                            child: _secretWord == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                                    child:
                                        SecretWordCard(
                                          key: ValueKey(_secretWord!.normalizedWord),
                                          displayWord: _secretWord!.displayWord,
                                          found: _secretFound,
                                        ).animate().scale(
                                          begin: const Offset(0.4, 0.4),
                                          curve: Curves.elasticOut,
                                          duration: 700.ms,
                                        ),
                                  ),
                          ),
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
                                          child: GridBoard(
                                            key: _boardKey,
                                            letters: session.board.letters,
                                            onPathSubmitted: _onPathSubmitted,
                                            isPathAcceptable: session.wouldAccept,
                                            onWordChanged: _onWordChanging,
                                            boardSkin: boardSkin,
                                            letterSkin: letterSkin,
                                            markerSkin: markerSkin,
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
                                name: 'שלי',
                                avatarId: profile?.avatarId ?? 'detective',
                                words: session.foundNormalizedWords.map((w) => HebrewTrie.toDisplayWord(w)).toList(),
                                isMe: true,
                              ),
                              opponents: [
                                for (final p in _room?.players ?? const <PlayerInRoom>[])
                                  if (p.uid != _myUid)
                                    RaceWordList(
                                      name: p.displayName,
                                      avatarId: p.avatarId ?? 'detective',
                                      words: p.words,
                                    ),
                              ],
                              unlocked: _spyUnlocked,
                              onUnlock: _unlockSpy,
                              confirmInline: true,
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

/// עזרים במשחק מול חברים: 💡 רמז (עם מונה) ו-🔎 גלה מילה (במטבעות).
class _HelperRow extends ConsumerWidget {
  final VoidCallback onHint;
  final VoidCallback onReveal;

  const _HelperRow({required this.onHint, required this.onReveal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hints = ref.watch(playerProfileProvider).valueOrNull?.hints ?? 0;
    Widget button({
      required String label,
      required IconData icon,
      required List<Color> colors,
      required Color ink,
      required String badge,
      required VoidCallback onTap,
    }) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.6), offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ink, size: 19),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        button(
          label: 'רמז',
          icon: Icons.lightbulb_rounded,
          colors: const [Color(0xFFFFF0A8), Color(0xFFFFB700)],
          ink: const Color(0xFF5A3300),
          badge: '$hints',
          onTap: onHint,
        ),
        const SizedBox(width: 8),
        button(
          label: 'גלה מילה',
          icon: Icons.manage_search_rounded,
          colors: const [Color(0xFFB57BFF), Color(0xFF7B3FF2)],
          ink: Colors.white,
          badge: '${CoinCosts.revealWord}🪙',
          onTap: onReveal,
        ),
      ],
    );
  }
}
