import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/analytics/analytics_route_observer.dart';
import 'package:wordbox_hebrew/core/analytics/analytics_service.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

void main() {
  group('AnalyticsService.sanitizeParams', () {
    test('drops nulls, maps bools to 1/0, adds game_version', () {
      final out = AnalyticsService.sanitizeParams({'a': null, 'ok': true, 'no': false, 'n': 3});
      expect(out.containsKey('a'), isFalse);
      expect(out['ok'], 1);
      expect(out['no'], 0);
      expect(out['n'], 3);
      expect(out['game_version'], AnalyticsService.gameVersion);
    });

    test('truncates strings to 100 chars and caps at 25 params', () {
      final out = AnalyticsService.sanitizeParams({
        'long': 'x' * 150,
        for (var i = 0; i < 40; i++) 'p$i': i,
      });
      expect((out['long'] as String).length, 100);
      expect(out.length, lessThanOrEqualTo(25));
    });
  });

  test('is a safe no-op when never initialized (tests / Firebase off)', () async {
    final analytics = AnalyticsService.instance;
    final level = CampaignLevels.byLevelNumber(1);
    final first = await analytics.levelStart(level);
    final second = await analytics.levelStart(level);
    expect(second, first + 1);
    analytics
      ..levelEnd(
        config: level,
        attempt: second,
        success: true,
        score: 10,
        stars: 3,
        wordsFound: 4,
        wordsPossible: 9,
        timeSec: 20,
        wallSec: 25,
        hintsUsed: 0,
        reason: 'win',
      )
      ..setAuthUser(null)
      ..setProgress(highestUnlockedLevel: 26)
      ..worldUnlockedIfCrossed(highestBefore: 25, highestAfter: 26);
    await analytics.applyAdsConsent(AdsConsentState.notRequired);
    expect(analytics.isEnabled, isFalse);
  });

  test('route observer maps locations to clean screen names', () {
    expect(AnalyticsRouteObserver.screenFor('/'), ('splash', null));
    expect(AnalyticsRouteObserver.screenFor('/level/12/play'), ('level_play', 12));
    expect(AnalyticsRouteObserver.screenFor('/level/3/result'), ('level_result', 3));
    expect(AnalyticsRouteObserver.screenFor('/store?from=home'), ('store', null));
    expect(AnalyticsRouteObserver.screenFor('/multiplayer/online/room/12345'), ('room_lobby', null));
    expect(AnalyticsRouteObserver.screenFor('/multiplayer/online/room/12345/result'), ('online_race_result', null));
    expect(AnalyticsRouteObserver.screenFor('/multiplayer/online/race/12345'), ('online_race', null));
    expect(AnalyticsRouteObserver.screenFor('/multiplayer/online/join?code=1&auto=1'), ('room_join', null));
  });
}
