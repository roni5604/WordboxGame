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

  group('CampaignLevels.wordsRequiredForLevel / difficulty progression', () {
    test('wordsRequired grows from 3 (level 1) then rises gently across the whole game', () {
      expect(CampaignLevels.byLevelNumber(1).wordsRequired, 3);
      expect(CampaignLevels.byLevelNumber(2).wordsRequired, 4);
      for (int i = 3; i <= 100; i++) {
        final words = CampaignLevels.byLevelNumber(i).wordsRequired;
        expect(words, inInclusiveRange(5, 11), reason: 'level $i');
      }
    });

    test('does NOT reset at world boundaries: first normal level of a new world is not easier '
        'than the last normal level of the previous world', () {
      // משווים שלבים "רגילים" (לא מאסטר/פינאלה) משני צידי הגבול, כדי
      // לוודא שהקושי הבסיסי לא "קופץ אחורה" בתחילת עולם חדש.
      final lastNormalOfWorld1 = CampaignLevels.byLevelNumber(23); // 24=master, 25=finale
      final firstNormalOfWorld2 = CampaignLevels.byLevelNumber(27); // 26 still fine too
      expect(
        firstNormalOfWorld2.wordsRequired,
        greaterThanOrEqualTo(lastNormalOfWorld1.wordsRequired),
      );
    });

    test('master levels require at least as many words as a normal level at the same point',
        () {
      final master = CampaignLevels.byLevelNumber(12);
      final normalNeighbor = CampaignLevels.byLevelNumber(11);
      expect(master.wordsRequired, greaterThanOrEqualTo(normalNeighbor.wordsRequired));
    });

    test('worldFinale requires more words than the master level right before it', () {
      final master = CampaignLevels.byLevelNumber(24);
      final finale = CampaignLevels.byLevelNumber(25);
      expect(finale.wordsRequired, greaterThan(master.wordsRequired));
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

    test('master/finale levels get less time than a normal level with the same words/gridSize',
        () {
      final normalTime = CampaignLevels.timeLimitForLevel(
        wordsRequired: 6,
        gridSize: 4,
        kind: LevelKind.normal,
      );
      final masterTime = CampaignLevels.timeLimitForLevel(
        wordsRequired: 6,
        gridSize: 4,
        kind: LevelKind.master,
      );
      final finaleTime = CampaignLevels.timeLimitForLevel(
        wordsRequired: 6,
        gridSize: 4,
        kind: LevelKind.worldFinale,
      );
      expect(masterTime, lessThan(normalTime));
      expect(finaleTime, lessThanOrEqualTo(masterTime));
    });
  });
}
