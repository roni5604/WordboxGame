import 'package:go_router/go_router.dart';

import '../../features/game/level_intro_screen.dart';
import '../../features/game/level_result_screen.dart';
import '../../features/game/game_screen.dart';
import '../../features/home/campaign_map_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/multiplayer/models/race_config.dart';
import '../../features/multiplayer/models/race_result.dart';
import '../../features/multiplayer/multiplayer_home_screen.dart';
import '../../features/multiplayer/race_game_screen.dart';
import '../../features/multiplayer/race_result_screen.dart';
import '../../features/multiplayer/race_setup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/rules/rules_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/store/store_screen.dart';

/// כל הניתוב של האפליקציה מרוכז כאן (go_router), כולל תמיכה בכתובות URL
/// עבור גרסת ה-Web (למשל /level/12/intro ניתן לשיתוף/רענון ישיר בדפדפן).
///
/// מבנה הניווט: / (splash) -> /onboarding (פעם ראשונה) -> /home (תפריט
/// ראשי) -> /campaign (מפת השלבים) -> /level/:n/intro|play|result.
/// רב-משתתפים: /multiplayer -> /multiplayer/setup -> /multiplayer/race
/// -> /multiplayer/race/result.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/how-to-play',
      builder: (context, state) => const OnboardingScreen(standalone: true),
    ),
    GoRoute(path: '/rules', builder: (context, state) => const RulesScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/campaign', builder: (context, state) => const CampaignMapScreen()),
    GoRoute(
      path: '/level/:levelNumber/intro',
      builder: (context, state) => LevelIntroScreen(
        levelNumber: int.parse(state.pathParameters['levelNumber']!),
      ),
    ),
    GoRoute(
      path: '/level/:levelNumber/play',
      builder: (context, state) => GameScreen(
        levelNumber: int.parse(state.pathParameters['levelNumber']!),
      ),
    ),
    GoRoute(
      path: '/level/:levelNumber/result',
      builder: (context, state) => LevelResultScreen(
        levelNumber: int.parse(state.pathParameters['levelNumber']!),
        result: state.extra as GameScreenResult,
      ),
    ),
    GoRoute(
      path: '/multiplayer',
      builder: (context, state) => const MultiplayerHomeScreen(),
    ),
    GoRoute(
      path: '/multiplayer/setup',
      builder: (context, state) => const RaceSetupScreen(),
    ),
    GoRoute(
      path: '/multiplayer/race',
      builder: (context, state) => RaceGameScreen(config: state.extra as RaceConfig),
    ),
    GoRoute(
      path: '/multiplayer/race/result',
      builder: (context, state) => RaceResultScreen(result: state.extra as RaceResult),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
  ],
);
