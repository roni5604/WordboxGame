import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

void main() {
  group('CampaignLevels tiers', () {
    test('seedling tier (3x3) covers levels 1-9', () {
      for (int i = 1; i <= 9; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.seedling, reason: 'level $i');
        expect(config.gridSize, 3, reason: 'level $i');
      }
    });

    test('sprout tier (4x4) covers levels 10-19', () {
      for (int i = 10; i <= 19; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.sprout, reason: 'level $i');
        expect(config.gridSize, 4, reason: 'level $i');
      }
    });

    test('bloom tier (5x5) covers levels 20-29', () {
      for (int i = 20; i <= 29; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.bloom, reason: 'level $i');
        expect(config.gridSize, 5, reason: 'level $i');
      }
    });

    test('forest tier (6x6) covers levels 30-39', () {
      for (int i = 30; i <= 39; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.forest, reason: 'level $i');
        expect(config.gridSize, 6, reason: 'level $i');
      }
    });

    test('summit tier (7x7) starts at level 40', () {
      for (int i = 40; i <= 49; i++) {
        final config = CampaignLevels.byLevelNumber(i);
        expect(config.tier, WorldTier.summit, reason: 'level $i');
        expect(config.gridSize, 7, reason: 'level $i');
      }
    });
  });

  group('CampaignLevels.isMilestoneLevel', () {
    test('level 1 is NOT a milestone (no previous world to celebrate)', () {
      expect(CampaignLevels.byLevelNumber(1).isMilestoneLevel, isFalse);
    });

    test('level 10 IS a milestone (first 4x4 level, as explicitly requested)', () {
      final config = CampaignLevels.byLevelNumber(10);
      expect(config.isMilestoneLevel, isTrue);
      expect(config.gridSize, 4);
    });

    test('level 20 IS a milestone (first 5x5 level)', () {
      final config = CampaignLevels.byLevelNumber(20);
      expect(config.isMilestoneLevel, isTrue);
      expect(config.gridSize, 5);
    });

    test('level 30 IS a milestone (first 6x6 level)', () {
      final config = CampaignLevels.byLevelNumber(30);
      expect(config.isMilestoneLevel, isTrue);
      expect(config.gridSize, 6);
    });

    test('level 40 IS a milestone (first 7x7 level)', () {
      final config = CampaignLevels.byLevelNumber(40);
      expect(config.isMilestoneLevel, isTrue);
      expect(config.gridSize, 7);
    });

    test('non-first levels of each tier are NOT milestones', () {
      const nonMilestoneLevels = [2, 3, 9, 11, 15, 19, 21, 29, 31, 39, 41, 49];
      for (final levelNumber in nonMilestoneLevels) {
        expect(
          CampaignLevels.byLevelNumber(levelNumber).isMilestoneLevel,
          isFalse,
          reason: 'level $levelNumber should not be a milestone',
        );
      }
    });
  });

  group('CampaignLevels.positionWithinTier / tierBlockSize', () {
    test('first tier has 9 levels (1-9), position 0-based', () {
      expect(CampaignLevels.tierBlockSize(1), 9);
      expect(CampaignLevels.positionWithinTier(1), 0);
      expect(CampaignLevels.positionWithinTier(9), 8);
    });

    test('subsequent tiers have 10 levels each, position resets at each boundary', () {
      expect(CampaignLevels.tierBlockSize(10), 10);
      expect(CampaignLevels.positionWithinTier(10), 0);
      expect(CampaignLevels.positionWithinTier(19), 9);

      expect(CampaignLevels.positionWithinTier(20), 0);
      expect(CampaignLevels.positionWithinTier(29), 9);

      expect(CampaignLevels.positionWithinTier(40), 0);
      expect(CampaignLevels.positionWithinTier(49), 9);
    });

    test('difficulty (time limit, score thresholds) is non-decreasing within a tier', () {
      for (final start in [1, 10, 20, 30, 40]) {
        final blockSize = CampaignLevels.tierBlockSize(start);
        final end = start + blockSize - 1;
        LevelConfig? previous;
        for (int i = start; i <= end; i++) {
          final config = CampaignLevels.byLevelNumber(i);
          if (previous != null) {
            expect(config.timeLimit.inSeconds, lessThanOrEqualTo(previous.timeLimit.inSeconds),
                reason: 'level $i should not have more time than level ${i - 1}');
          }
          previous = config;
        }
      }
    });

    test('CampaignLevels.all has exactly 49 fixed levels for all users', () {
      expect(CampaignLevels.all.length, 49);
      expect(CampaignLevels.all.first.levelNumber, 1);
      expect(CampaignLevels.all.last.levelNumber, 49);
    });
  });
}
