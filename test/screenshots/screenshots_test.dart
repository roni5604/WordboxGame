// צילומי מסך של מסכי האפליקציה בגודל אייפון (כולל notch ופס בית), לבדיקה
// ויזואלית ידנית. רץ רק כשמגדירים SCREENSHOTS_DIR (ונתיב לגופן עברי ב-
// HEEBO_TTF), כדי שלא יאט את ה-CI:
//   SCREENSHOTS_DIR=/tmp/shots HEEBO_TTF=/path/Heebo.ttf flutter test test/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/core/router/transitions.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';
import 'package:wordbox_hebrew/core/theme/app_colors.dart';
import 'package:wordbox_hebrew/data/models/level_progress.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/daily/daily_challenge_game_screen.dart';
import 'package:wordbox_hebrew/features/daily/daily_challenge_screen.dart';
import 'package:wordbox_hebrew/features/game/game_screen.dart';
import 'package:wordbox_hebrew/game_engine/daily_challenge.dart';
import 'package:wordbox_hebrew/features/onboarding/onboarding_screen.dart';
import 'package:wordbox_hebrew/features/game/level_result_screen.dart';
import 'package:wordbox_hebrew/features/share/share_achievement_sheet.dart';
import 'package:wordbox_hebrew/features/home/campaign_map_screen.dart';
import 'package:wordbox_hebrew/features/home/home_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/create_room_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/join_room_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/race_config.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/race_result.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_game_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_result_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_setup_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/room_lobby_screen.dart';
import 'package:wordbox_hebrew/features/settings/settings_screen.dart';
import 'package:wordbox_hebrew/features/profile/profile_screen.dart';
import 'package:wordbox_hebrew/features/rules/rules_screen.dart';
import 'package:wordbox_hebrew/features/store/store_screen.dart';
import 'package:wordbox_hebrew/features/game/level_intro_screen.dart';
import 'package:wordbox_hebrew/game_engine/bot_player.dart';
import 'package:wordbox_hebrew/features/social/friends_screen.dart';
import 'package:wordbox_hebrew/features/social/models/social_models.dart';
import 'package:wordbox_hebrew/features/social/play_with_friends_screen.dart';
import 'package:wordbox_hebrew/features/social/widgets/invite_dialog.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/social_provider.dart';

import '../features/multiplayer/fake_multiplayer_repository.dart';
import '../features/social/fake_social_repository.dart';

final _outDir = Platform.environment['SCREENSHOTS_DIR'];
final _only = Platform.environment['SCREENSHOTS_ONLY'];

class _Progress implements ProgressRepository {
  final bool daily;
  _Progress({this.daily = false});

  @override
  Future<PlayerProfile> loadProfile() async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return PlayerProfile(
      displayName: 'רוני',
      coins: 340,
      hints: 6,
      highestUnlockedLevel: 9,
      lastHintClaimDate: today,
      onboardingCompleted: true,
      authIntroShown: true,
      level1TutorialSeen: true,
      dailyChallengeDate: daily ? today : null,
      dailyChallengeScore: daily ? 48 : 0,
      dailyChallengeWords: daily ? 11 : 0,
      dailyChallengeStreak: daily ? 4 : 0,
      dailyChallengeBestStreak: 4,
      levelProgress: {
        for (int i = 1; i < 9; i++) i: LevelProgress(levelNumber: i, stars: i % 3 + 1, bestScore: 40, completed: true),
      },
    );
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

FakeSocialRepository _social() {
  final now = DateTime.now();
  final todayKey = DailyChallenge.dateKeyFor(now);
  PublicProfile p(String uid, String name, PresenceStatus s, int stars, int wins, {Duration ago = Duration.zero, int? daily}) =>
      PublicProfile(
        dailyDate: daily == null ? null : todayKey,
        dailyScore: daily ?? 0,
        uid: uid,
        displayName: name,
        friendCode: 'ABC234',
        totalStars: stars,
        highestLevel: stars ~/ 2,
        mpWins: wins,
        mpGames: wins + 3,
        status: s,
        lastActive: now.subtract(ago),
      );
  return FakeSocialRepository(
    myUid: 'me-uid',
    friends: [
      FriendEntry(profile: p('a', 'נועה', PresenceStatus.online, 41, 12, daily: 61), record: const FriendRecord(uid: 'a', games: 7, wins: 4, losses: 3)),
      FriendEntry(profile: p('b', 'איתי', PresenceStatus.playing, 18, 5, daily: 33), record: const FriendRecord(uid: 'b', games: 2, wins: 1, losses: 1)),
      FriendEntry(profile: p('c', 'מאיה', PresenceStatus.online, 55, 20), record: const FriendRecord(uid: 'c', games: 3, wins: 2, losses: 1)),
      FriendEntry(profile: p('d', 'יובל', PresenceStatus.offline, 9, 1, ago: const Duration(days: 2)), record: const FriendRecord(uid: 'd')),
    ],
    incoming: [
      FriendRequest(id: 'x_me', fromUid: 'x', toUid: 'me-uid', fromName: 'דנה', createdAt: now.subtract(const Duration(minutes: 12))),
    ],
    outgoing: const [
      FriendRequest(id: 'me_y', fromUid: 'me-uid', toUid: 'y', fromName: 'רוני', toName: 'שירה'),
    ],
  );
}

Future<void> _loadFonts() async {
  final heebo = File(Platform.environment['HEEBO_TTF']!).readAsBytesSync();
  final loader = FontLoader('Heebo')..addFont(Future.value(ByteData.view(Uint8List.fromList(heebo).buffer)));
  await loader.load();
  final root = Platform.environment['FLUTTER_ROOT']!;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  final iconLoader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(Uint8List.fromList(icons).buffer)));
  await iconLoader.load();
}

ThemeData _theme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Heebo',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
    pageTransitionsTheme: kPageTransitionsTheme,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark, fontFamily: 'Heebo'),
  );
}

final _boundary = GlobalKey();

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget Function() screen, {
  FakeSocialRepository? social,
  FakeMultiplayerRepository? multiplayer,
  _Progress? progress,
  Future<void> Function(WidgetTester tester)? interact,
  Duration settle = const Duration(milliseconds: 1500),
  int realWaitSeconds = 0,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/s',
    routes: [
      GoRoute(path: '/s', builder: (_, __) => screen()),
      GoRoute(path: '/:rest(.*)', builder: (_, __) => const SizedBox()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(progress ?? _Progress()),
        socialRepositoryProvider.overrideWithValue(social ?? _social()),
        soundServiceProvider.overrideWithValue(SoundService.silent()),
        if (multiplayer != null) multiplayerRepositoryProvider.overrideWithValue(multiplayer),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          routerConfig: router,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    ),
  );
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // טעינות אמיתיות (מילון מהנכסים וכו') לא מתקדמות בזמן המדומה של הבדיקה.
  for (int i = 0; i < realWaitSeconds * 2; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (interact != null) await interact(tester);
  await tester.pump(settle);

  // טעינת תמונות (אוואטארים, קמע) לפני הצילום.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));

  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  Directory(_outDir!).createSync(recursive: true);
  File('$_outDir/$name.png').writeAsBytesSync(bytes!);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  final skip = _outDir == null;
  bool want(String name) => _only == null || _only!.split(',').contains(name);

  setUpAll(() async {
    if (!skip) await _loadFonts();
  });

  GameRoom room() => GameRoom(
        roomCode: '48213',
        status: RoomStatus.waiting,
        hostUid: 'me-uid',
        gridSize: 5,
        roundSeconds: 90,
        joinDeadline: DateTime.now().add(const Duration(minutes: 8)),
        entryFee: 10,
        pot: 30,
        players: const [
          PlayerInRoom(uid: 'me-uid', displayName: 'רוני', isHost: true, avatarId: 'detective'),
          PlayerInRoom(uid: 'a', displayName: 'נועה', avatarId: 'mascot'),
          PlayerInRoom(uid: 'z', displayName: 'עומר'),
        ],
      );

  final shots = <String, Future<void> Function(WidgetTester)>{
    'home': (t) => _shoot(t, 'home', () => const HomeScreen()),
    'friends': (t) => _shoot(t, 'friends', () => const FriendsScreen()),
    'friend_card': (t) => _shoot(
          t,
          'friend_card',
          () => const FriendsScreen(),
          interact: (tester) async {
            await tester.tap(find.text('נועה').last);
            await tester.pump(const Duration(milliseconds: 600));
          },
        ),
    'friends_requests': (t) => _shoot(t, 'friends_requests', () => const FriendsScreen(initialTab: 1)),
    'friends_leaderboard': (t) => _shoot(t, 'friends_leaderboard', () => const FriendsScreen(initialTab: 2)),
    'play_friends': (t) => _shoot(t, 'play_friends', () => const PlayWithFriendsScreen()),
    'create_room_invite': (t) => _shoot(
          t,
          'create_room_invite',
          () => const CreateRoomScreen(inviteFriendUid: 'a', inviteFriendName: 'נועה'),
          multiplayer: FakeMultiplayerRepository(),
        ),
    'join_room': (t) => _shoot(t, 'join_room', () => const JoinRoomScreen(initialCode: '48213'), multiplayer: FakeMultiplayerRepository()),
    'lobby': (t) {
      final mp = FakeMultiplayerRepository()..myUid = 'me-uid';
      return _shoot(
        t,
        'lobby',
        () => const RoomLobbyScreen(roomCode: '48213'),
        multiplayer: mp,
        interact: (tester) async {
          mp.pushRoomUpdate(room());
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    },
    'invite_dialog': (t) => _shoot(
          t,
          'invite_dialog',
          () => Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showInviteDialog(
                  context,
                  GameInvite(
                    id: 'i',
                    fromUid: 'a',
                    fromName: 'נועה',
                    toUid: 'me',
                    roomCode: '48213',
                    createdAt: DateTime.now().subtract(const Duration(seconds: 18)),
                  ),
                );
              });
              return const HomeScreen();
            },
          ),
        ),
    'race_setup': (t) => _shoot(t, 'race_setup', () => const RaceSetupScreen()),
    'campaign': (t) => _shoot(t, 'campaign', () => const CampaignMapScreen()),
    'level_intro': (t) => _shoot(t, 'level_intro', () => const LevelIntroScreen(levelNumber: 9)),
    'game': (t) => _shoot(t, 'game', () => const GameScreen(levelNumber: 9), settle: const Duration(seconds: 3), realWaitSeconds: 12),
    'race_game': (t) => _shoot(
          t,
          'race_game',
          () => const RaceGameScreen(
            config: RaceConfig(
              gridSize: 5,
              timeLimit: Duration(seconds: 90),
              humanName: 'רוני',
              bots: [BotSetup(name: 'נועה', difficulty: BotDifficulty.normal)],
            ),
          ),
          settle: const Duration(seconds: 4),
          realWaitSeconds: 12,
        ),
    'level_result': (t) => _shoot(
          t,
          'level_result',
          () => const LevelResultScreen(
            levelNumber: 9,
            result: GameScreenResult(
              score: 64,
              stars: 3,
              foundWordsCount: 11,
              totalPossibleWords: 30,
              totalPossibleScore: 200,
              foundWordsDisplay: ['שלום'],
              coinsEarned: 52,
            ),
          ),
          settle: const Duration(seconds: 3),
        ),
    'share_sheet': (t) => _shoot(
          t,
          'share_sheet',
          () => Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showShareAchievementSheet(
                  context,
                  ShareAchievement.level(
                    levelNumber: 9,
                    stars: 3,
                    score: 64,
                    words: 11,
                    colors: AppColors.gradientForWorldIndex(0),
                  ),
                );
              });
              return const SizedBox.expand(child: ColoredBox(color: Colors.orange));
            },
          ),
        ),
    'race_result': (t) => _shoot(
          t,
          'race_result',
          () => const RaceResultScreen(
            result: RaceResult(rankedParticipants: [
              RaceParticipantResult(name: 'רוני', score: 48, wordsFound: 9, isHuman: true),
              RaceParticipantResult(name: 'נועה', score: 31, wordsFound: 6, isHuman: false),
            ]),
          ),
          settle: const Duration(seconds: 3),
        ),
    'onboarding': (t) => _shoot(t, 'onboarding', () => const OnboardingScreen(standalone: true)),
    'daily': (t) => _shoot(t, 'daily', () => const DailyChallengeScreen()),
    'daily_play': (t) => _shoot(
          t,
          'daily_play',
          () => const DailyChallengeGameScreen(),
          settle: const Duration(seconds: 4),
          realWaitSeconds: 12,
        ),
    'daily_done': (t) => _shoot(
          t,
          'daily_done',
          () => const DailyChallengeScreen(
            args: DailyChallengeArgs(
              outcome: DailyChallengeOutcome(score: 48, words: 11, streak: 4, coins: 54, newBestStreak: true),
            ),
          ),
          progress: _Progress(daily: true),
        ),
    'settings': (t) => _shoot(t, 'settings', () => const SettingsScreen()),
    'profile': (t) => _shoot(t, 'profile', () => const ProfileScreen()),
    'rules': (t) => _shoot(t, 'rules', () => const RulesScreen()),
    'store': (t) => _shoot(t, 'store', () => const StoreScreen()),
  };

  for (final entry in shots.entries) {
    testWidgets('screenshot ${entry.key}', (tester) async {
      await entry.value(tester);
    }, skip: skip || !want(entry.key));
  }
}
