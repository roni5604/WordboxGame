import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// Sends a GA4 `screen_view` with a clean, stable screen name for every
/// go_router page (see app_router.dart). Dialogs/sheets are ignored. Route
/// parameters are stripped from the name (room codes never reach analytics);
/// the campaign level number is sent as the `level_id` parameter instead.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({AnalyticsService? analytics}) : _analytics = analytics ?? AnalyticsService.instance;

  final AnalyticsService _analytics;
  Route<dynamic>? _lastLogged;

  /// Maps a location such as `/level/12/play?x=1` to (`level_play`, 12).
  static (String, int?) screenFor(String location) {
    final uri = Uri.tryParse(location);
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const <String>[];
    if (segments.isEmpty) return ('splash', null);
    final path = '/${segments.join('/')}';

    if (segments.first == 'level' && segments.length == 3) {
      final level = int.tryParse(segments[1]);
      return ('level_${segments[2]}', level);
    }
    if (path.startsWith('/multiplayer/online/room/')) {
      return (segments.length >= 5 && segments.last == 'result' ? 'online_race_result' : 'room_lobby', null);
    }
    if (path.startsWith('/multiplayer/online/race/')) return ('online_race', null);

    const names = <String, String>{
      '/onboarding': 'onboarding',
      '/how-to-play': 'how_to_play',
      '/rules': 'rules',
      '/home': 'home',
      '/campaign': 'campaign_map',
      '/multiplayer/setup': 'race_setup',
      '/multiplayer/race': 'race_game',
      '/multiplayer/race/result': 'race_result',
      '/multiplayer/online/create': 'room_create',
      '/multiplayer/online/join': 'room_join',
      '/play/friends': 'play_with_friends',
      '/friends': 'friends',
      '/daily': 'daily',
      '/daily/play': 'daily_play',
      '/profile': 'profile',
      '/settings': 'settings',
      '/store': 'store',
      '/auth': 'auth',
    };
    return (names[path] ?? 'other', null);
  }

  void _send(Route<dynamic>? route) {
    try {
      if (route is! PageRoute) return;
      final name = route.settings.name;
      if (name == null || identical(route, _lastLogged)) return;
      _lastLogged = route;
      final (screen, levelId) = screenFor(name);
      _analytics.screenView(screen, levelId: levelId);
    } catch (e) {
      debugPrint('[analytics] screen_view skipped: $e');
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _send(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _send(previousRoute);
  }
}
