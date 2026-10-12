import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_route_observer.dart';
import '../platform/top_bar_tint.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/daily/daily_challenge_game_screen.dart';
import '../../features/daily/daily_challenge_screen.dart';
import '../../features/game/level_intro_screen.dart';
import '../../features/game/level_result_screen.dart';
import '../../features/game/game_screen.dart';
import '../../features/home/campaign_map_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/multiplayer/create_room_screen.dart';
import '../../features/multiplayer/join_room_screen.dart';
import '../../features/multiplayer/models/race_config.dart';
import '../../features/multiplayer/models/race_result.dart';
import '../../features/multiplayer/online_race_result_screen.dart';
import '../../features/multiplayer/online_race_screen.dart';
import '../../features/multiplayer/race_game_screen.dart';
import '../../features/multiplayer/race_result_screen.dart';
import '../../features/multiplayer/race_setup_screen.dart';
import '../../features/multiplayer/room_lobby_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/rules/rules_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/social/friends_screen.dart';
import '../../features/social/play_with_friends_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/store/store_screen.dart';
import 'transitions.dart';

/// מפתח ה-Navigator הראשי - מאפשר לחלונות גלובליים (הזמנה למשחק מחבר/ה)
/// להיפתח מכל מקום באפליקציה. ראו lib/features/social/social_host.dart.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// כל הניתוב של האפליקציה מרוכז כאן (go_router), כולל תמיכה בכתובות URL
/// עבור גרסת ה-Web (למשל /level/12/intro ניתן לשיתוף/רענון ישיר בדפדפן).
///
/// מבנה הניווט: / (splash) -> /onboarding (פעם ראשונה) -> /home (תפריט
/// ראשי) -> /campaign (מפת השלבים) -> /level/:n/intro|play|result.
/// נגד המחשב: /multiplayer/setup -> /multiplayer/race -> /multiplayer/race/result.
/// נגד חברים: /play/friends -> /multiplayer/online/create או
/// /multiplayer/online/join -> /multiplayer/online/room/:roomCode ->
/// /multiplayer/online/race/:roomCode -> /multiplayer/online/room/:roomCode/result.
/// חברים (רשימה, בקשות, דירוג): /friends.
///
/// מסכי משחק משתמשים ב-[gamePage] (בלי החלקה אחורה), מסכי תפריט ב-[appPage]
/// (החלקה אחורה טבעית), וחנות/פרופיל/חברים ב-[popupPage]. ראו transitions.dart.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  // באתר: הפס העליון של הדפדפן מוחשך כשנפתח דיאלוג (ראו top_bar_tint.dart).
  // screen_view לכל מסך (שמות נקיים, בלי קודי חדר) - ראו analytics_route_observer.dart.
  observers: [TopTintObserver(), AnalyticsRouteObserver()],
  routes: [
    GoRoute(path: '/', pageBuilder: (context, state) => gamePage(state, const SplashScreen())),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => gamePage(state, const OnboardingScreen()),
    ),
    GoRoute(
      path: '/how-to-play',
      pageBuilder: (context, state) => appPage(state, const OnboardingScreen(standalone: true)),
    ),
    GoRoute(path: '/rules', pageBuilder: (context, state) => appPage(state, const RulesScreen())),
    GoRoute(path: '/home', pageBuilder: (context, state) => gamePage(state, const HomeScreen())),
    GoRoute(
      path: '/campaign',
      pageBuilder: (context, state) => gamePage(state, const CampaignMapScreen()),
    ),
    GoRoute(
      path: '/level/:levelNumber/intro',
      pageBuilder: (context, state) => gamePage(
        state,
        LevelIntroScreen(levelNumber: int.parse(state.pathParameters['levelNumber']!)),
      ),
    ),
    GoRoute(
      path: '/level/:levelNumber/play',
      pageBuilder: (context, state) => gamePage(
        state,
        GameScreen(levelNumber: int.parse(state.pathParameters['levelNumber']!)),
      ),
    ),
    GoRoute(
      path: '/level/:levelNumber/result',
      pageBuilder: (context, state) => gamePage(
        state,
        LevelResultScreen(
          levelNumber: int.parse(state.pathParameters['levelNumber']!),
          result: state.extra as GameScreenResult,
        ),
      ),
    ),
    // "רב-משתתפים" פוצל לשני כפתורים במסך הבית: נגד המחשב / נגד חברים.
    // הכתובת הישנה ממשיכה לעבוד ומפנה למסך החברים.
    GoRoute(path: '/multiplayer', redirect: (context, state) => '/play/friends'),
    GoRoute(
      path: '/multiplayer/setup',
      pageBuilder: (context, state) => appPage(state, const RaceSetupScreen()),
    ),
    GoRoute(
      path: '/multiplayer/race',
      pageBuilder: (context, state) => gamePage(state, RaceGameScreen(config: state.extra as RaceConfig)),
    ),
    GoRoute(
      path: '/multiplayer/race/result',
      pageBuilder: (context, state) => gamePage(state, RaceResultScreen(result: state.extra as RaceResult)),
    ),
    GoRoute(
      path: '/play/friends',
      pageBuilder: (context, state) => appPage(state, const PlayWithFriendsScreen()),
    ),
    GoRoute(
      path: '/friends',
      pageBuilder: (context, state) => popupPage(
        state,
        FriendsScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0),
      ),
    ),
    GoRoute(
      path: '/multiplayer/online/create',
      pageBuilder: (context, state) => appPage(
        state,
        CreateRoomScreen(
          inviteFriendUid: state.uri.queryParameters['invite'],
          inviteFriendName: state.uri.queryParameters['inviteName'],
        ),
      ),
    ),
    GoRoute(
      path: '/multiplayer/online/join',
      pageBuilder: (context, state) => appPage(
        state,
        JoinRoomScreen(
          initialCode: state.uri.queryParameters['code'],
          autoJoin: state.uri.queryParameters['auto'] == '1',
        ),
      ),
    ),
    // קישור קצר לשיתוף בוואטסאפ: .../#/join/12345
    GoRoute(
      path: '/join/:roomCode',
      redirect: (context, state) =>
          '/multiplayer/online/join?code=${state.pathParameters['roomCode']}',
    ),
    GoRoute(
      path: '/multiplayer/online/room/:roomCode',
      pageBuilder: (context, state) =>
          appPage(state, RoomLobbyScreen(roomCode: state.pathParameters['roomCode']!)),
    ),
    GoRoute(
      path: '/multiplayer/online/race/:roomCode',
      pageBuilder: (context, state) =>
          gamePage(state, OnlineRaceScreen(roomCode: state.pathParameters['roomCode']!)),
    ),
    GoRoute(
      path: '/multiplayer/online/room/:roomCode/result',
      pageBuilder: (context, state) => gamePage(
        state,
        OnlineRaceResultScreen(
          roomCode: state.pathParameters['roomCode']!,
          result: state.extra as RaceResult,
        ),
      ),
    ),
    GoRoute(
      path: '/daily',
      pageBuilder: (context, state) => gamePage(
        state,
        DailyChallengeScreen(args: state.extra is DailyChallengeArgs ? state.extra as DailyChallengeArgs : null),
      ),
    ),
    GoRoute(path: '/daily/play', pageBuilder: (context, state) => gamePage(state, const DailyChallengeGameScreen())),
    GoRoute(path: '/profile', pageBuilder: (context, state) => popupPage(state, const ProfileScreen())),
    GoRoute(path: '/settings', pageBuilder: (context, state) => appPage(state, const SettingsScreen())),
    GoRoute(
      path: '/store',
      pageBuilder: (context, state) =>
          popupPage(state, StoreScreen(source: state.uri.queryParameters['from'] ?? 'other')),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => appPage(
        state,
        AuthScreen(isInitial: state.uri.queryParameters['initial'] == 'true'),
      ),
    ),
  ],
);
