import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

void main() {
  group('CampaignLevels world boundaries (4 worlds x 25 levels = 100 total)', () {
    test('seedling tier (3x3) covers levels 1-25', () {
      for (int i = 1; i <= 25; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.seedling, reason: 'level $i');
        expect(config.gridSize, 3, reason: 'level $i');
      }
    });

    test('sprout tier (4x4) covers levels 26-50', () {
      for (int i = 26; i <= 50; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.sprout, reason: 'level $i');
        expect(config.gridSize, 4, reason: 'level $i');
      }
    });

    test('bloom tier (5x5) covers levels 51-75', () {
      for (int i = 51; i <= 75; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.bloom, reason: 'level $i');
        expect(config.gridSize, 5, reason: 'level $i');
      }
    });

    test('forest tier (6x6) covers levels 76-100', () {
      for (int i = 76; i <= 100; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.forest, reason: 'level $i');
        expect(config.gridSize, 6, reason: 'level $i');
      }
    });

    test('CampaignLevels.all has exactly 100 fixed levels for all users', () {
      expect(CampaignLevels.all.length, 100);
      expect(CampaignLevels.all.first.levelNumber, 1);
      expect(CampaignLevels.all.last.levelNumber, 100);
      expect(CampaignLevels.totalLevels, 100);
    });
  });

  group('CampaignLevels.positionWithinWorld', () {
    test('resets to 1 at the start of every world (1, 26, 51, 76)', () {
      expect(CampaignLevels.positionWithinWorld(1), 1);
      expect(CampaignLevels.positionWithinWorld(26), 1);
      expect(CampaignLevels.positionWithinWorld(51), 1);
      expect(CampaignLevels.positionWithinWorld(76), 1);
    });

    test('reaches 25 (levelsPerWorld) at the end of every world (25, 50, 75, 100)', () {
      expect(CampaignLevels.positionWithinWorld(25), 25);
      expect(CampaignLevels.positionWithinWorld(50), 25);
      expect(CampaignLevels.positionWithinWorld(75), 25);
      expect(CampaignLevels.positionWithinWorld(100), 25);
    });
  });

  group('LevelConfig.kind (normal/master/worldFinale)', () {
    test('the last level of every world (25/50/75/100) is a worldFinale', () {
      for (final levelNumber in [25, 50, 75, 100]) {
        final config = CampaignLevels.byLevelNumber(levelNumber);
        expect(config.kind, LevelKind.worldFinale, reason: 'level $levelNumber');
        expect(config.isWorldFinale, isTrue, reason: 'level $levelNumber');
        expect(config.isMasterLevel, isFalse, reason: 'level $levelNumber');
      }
    });

    test('master levels appear every 6th position within a world (6/12/18/24), not on the finale',
        () {
      // עולם ראשון (שלבים 1-25): מאסטר ב-6, 12, 18, 24.
      const expectedMasters = [6, 12, 18, 24];
      for (final position in expectedMasters) {
        final config = CampaignLevels.byLevelNumber(position);
        expect(config.kind, LevelKind.master, reason: 'level $position');
        expect(config.isMasterLevel, isTrue, reason: 'level $position');
      }
    });

    test('master cadence repeats identically in every world (offset by 25)', () {
      const expectedMasters = [6, 12, 18, 24];
      for (final offset in [0, 25, 50, 75]) {
        for (final position in expectedMasters) {
          final config = CampaignLevels.byLevelNumber(offset + position);
          expect(config.kind, LevelKind.master, reason: 'level ${offset + position}');
        }
      }
    });

    test('non-special levels are normal', () {
      const nonSpecialLevels = [1, 2, 5, 7, 11, 13, 17, 19, 23, 27, 30, 90, 98];
      for (final levelNumber in nonSpecialLevels) {
        final config = CampaignLevels.byLevelNumber(levelNumber);
        expect(config.kind, LevelKind.normal, reason: 'level $levelNumber');
      }
    });

    test('exactly 4 master levels and 1 finale per world (5 special levels per 25)', () {
      for (int worldIndex = 0; worldIndex < 4; worldIndex++) {
        final start = worldIndex * 25 + 1;
        final end = start + 24;
        final levels = [for (int i = start; i <= end; i++) CampaignLevels.byLevelNumber(i)];
        final masters = levels.where((l) => l.isMasterLevel).length;
        final finales = levels.where((l) => l.isWorldFinale).length;
        expect(masters, 4, reason: 'world starting at $start');
        expect(finales, 1, reason: 'world starting at $start');
      }
    });
  });

  group('CampaignLevels.globalProgress', () {
    test('is 0 at level 1 and 1.0 at the last level', () {
      expect(CampaignLevels.globalProgress(1), 0);
      expect(CampaignLevels.globalProgress(CampaignLevels.totalLevels), 1.0);
    });

    test('increases monotonically with level number', () {
      double previous = -1;
      for (int i = 1; i <= CampaignLevels.totalLevels; i++) {
        final g = CampaignLevels.globalProgress(i);
        expect(g, greaterThanOrEqualTo(previous), reason: 'level $i');
        previous = g;
      }
    });
  });

  group('CampaignLevels.scoreRequiredForLevel / difficulty progression', () {
    test('level 1 asks for 9 points, then the goal rises across the campaign', () {
      expect(CampaignLevels.byLevelNumber(1).scoreRequired, 9);
      expect(
        CampaignLevels.byLevelNumber(2).scoreRequired,
        greaterThan(CampaignLevels.byLevelNumber(1).scoreRequired),
      );
      for (int i = 1; i <= 100; i++) {
        final score = CampaignLevels.byLevelNumber(i).scoreRequired;
        expect(score, inInclusiveRange(9, 160), reason: 'level $i');
      }
    });

    test('does NOT reset at world boundaries: first normal level of a new world is not easier '
        'than the last normal level of the previous world', () {
      final lastNormalOfWorld1 = CampaignLevels.byLevelNumber(23);
      final firstNormalOfWorld2 = CampaignLevels.byLevelNumber(27);
      expect(
        firstNormalOfWorld2.scoreRequired,
        greaterThanOrEqualTo(lastNormalOfWorld1.scoreRequired),
      );
    });

    test('master levels require at least as many points as a normal neighbor', () {
      final master = CampaignLevels.byLevelNumber(12);
      final normalNeighbor = CampaignLevels.byLevelNumber(11);
      expect(master.scoreRequired, greaterThanOrEqualTo(normalNeighbor.scoreRequired));
    });

    test('worldFinale requires more points than the master level right before it', () {
      final master = CampaignLevels.byLevelNumber(24);
      final finale = CampaignLevels.byLevelNumber(25);
      expect(finale.scoreRequired, greaterThan(master.scoreRequired));
    });

    test('one star is a third of the score goal and three stars is the full goal', () {
      final config = CampaignLevels.byLevelNumber(1);
      expect(config.scoreRequired, 9);
      expect(config.oneStarScore, 3);
      expect(config.twoStarScore, 6);
      expect(config.threeStarScore, 9);
    });
  });

  group('CampaignLevels.timeLimitForLevel', () {
    test('timeLimit stays within a sane range for all 100 levels', () {
      for (int i = 1; i <= 100; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.timeLimit.inSeconds, inInclusiveRange(30, 150), reason: 'level $i');
      }
    });

    test('timeLimit is always a round number of seconds (multiple of 10)', () {
      for (int i = 1; i <= 100; i++) {
        final seconds = CampaignLevels.byLevelNumber(i).timeLimit.inSeconds;
        expect(seconds % 10, 0, reason: 'level $i should have a round time, got $seconds');
      }
    });

    test('level 1 has a comfortable margin (>=50s) but is still much shorter than the last level',
        () {
      final seconds = CampaignLevels.byLevelNumber(1).timeLimit.inSeconds;
      expect(seconds, greaterThanOrEqualTo(50));
      expect(seconds, lessThan(CampaignLevels.byLevelNumber(100).timeLimit.inSeconds));
    });

    test('master/finale levels get less time than a normal level with the same score/gridSize',
        () {
      final normalTime = CampaignLevels.timeLimitForLevel(
        scoreRequired: 18,
        gridSize: 4,
        kind: LevelKind.normal,
      );
      final masterTime = CampaignLevels.timeLimitForLevel(
        scoreRequired: 18,
        gridSize: 4,
        kind: LevelKind.master,
      );
      final finaleTime = CampaignLevels.timeLimitForLevel(
        scoreRequired: 18,
        gridSize: 4,
        kind: LevelKind.worldFinale,
      );
      expect(masterTime, lessThan(normalTime));
      expect(finaleTime, lessThanOrEqualTo(masterTime));
    });
  });
}
