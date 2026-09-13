import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/common_word_pool.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/level_board_builder.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelBoardBuilder builder;
  late HebrewTrie trie;
  late CommonWordPool pool;

  setUpAll(() async {
    final wordsRaw = await rootBundle.loadString('assets/dictionaries/he_words.json');
    final words = (jsonDecode(wordsRaw) as List).cast<String>();
    trie = HebrewTrie()..insertAll(words);

    final commonRaw = await rootBundle.loadString('assets/dictionaries/common_words.json');
    final commonWords = (jsonDecode(commonRaw) as List).cast<String>();
    pool = CommonWordPool(commonWords.toSet());

    final freqRaw = await rootBundle.loadString('assets/config/letter_frequency.json');
    final Map<String, dynamic> freqDecoded = jsonDecode(freqRaw) as Map<String, dynamic>;
    final weights = freqDecoded.map((k, v) => MapEntry(k, (v as num).toDouble()));

    builder = LevelBoardBuilder(trie: trie, letterWeights: weights, commonWords: pool);
  });

  test('builds a deterministic board for the same level number', () {
    final config = CampaignLevels.byLevelNumber(1);
    final first = builder.buildForLevel(config);
    final second = builder.buildForLevel(config);

    expect(first.board.letters, equals(second.board.letters));
  });

  test('builds different boards for different level numbers (usually)', () {
    final level1 = builder.buildForLevel(CampaignLevels.byLevelNumber(1));
    final level2 = builder.buildForLevel(CampaignLevels.byLevelNumber(2));

    expect(level1.board.letters, isNot(equals(level2.board.letters)));
  });

  test('board has correct dimensions and enough words for level 1 (3x3)', () {
    final config = CampaignLevels.byLevelNumber(1);
    final result = builder.buildForLevel(config);

    expect(result.board.size, 3);
    expect(result.board.letters.length, 3);
    expect(result.board.letters[0].length, 3);
    expect(result.board.possibleWords, isNotEmpty);
  });

  test('anchors words are common and their paths are valid adjacent sequences', () {
    final config = CampaignLevels.byLevelNumber(1);
    final result = builder.buildForLevel(config);

    expect(result.anchors, isNotEmpty);
    for (final anchor in result.anchors) {
      expect(pool.isCommon(anchor.normalizedWord), isTrue);
      expect(anchor.path.length, anchor.normalizedWord.length);
      for (int i = 1; i < anchor.path.length; i++) {
        expect(anchor.path[i].isAdjacentTo(anchor.path[i - 1]), isTrue);
      }
      // המילה שהוצבה חייבת להיות ניתנת לקריאה מהלוח בדיוק לפי הנתיב.
      final wordFromBoard =
          anchor.path.map((p) => result.board.letters[p.row][p.col]).join();
      expect(wordFromBoard, anchor.normalizedWord);
    }
  });

  test(
      'earlier (easier) level in the game tends to have more common-word anchors than a much '
      'later (harder) one - difficulty rises globally, not per-world', () {
    final easy = builder.buildForLevel(CampaignLevels.byLevelNumber(2)); // near start of game
    final hard = builder.buildForLevel(CampaignLevels.byLevelNumber(90)); // near end of game

    // לא דטרמיניסטית באופן מוחלט (תלוי בלוח שנוצר), אבל לשלב מוקדם מאוד
    // יש יותר עוגנים מובטחים משלב מאוחר מאוד - גם כששני השלבים "רגילים"
    // (לא מאסטר/פינאלה) ונמצאים בעולמות שונים.
    expect(easy.anchors.length, greaterThanOrEqualTo(hard.anchors.length));
  });

  test('a normal level right after a world boundary is not easier than one right before it '
      '(no difficulty reset between worlds)', () {
    // בודקים את יעד הקושי הדטרמיניסטי (BoardDifficultyProfile), לא את
    // כמות העוגנים שבפועל הצליחו להיכנס ללוח - זו האחרונה תלויה גם
    // בהצלחת ההצבה האקראית לכל מילה, ולכן רועשת מדי להשוואה ישירה בין
    // שני שלבים בודדים וסמוכים.
    final beforeBoundary =
        BoardDifficultyProfile.forLevel(CampaignLevels.byLevelNumber(23)); // last normal, world 1
    final afterBoundary =
        BoardDifficultyProfile.forLevel(CampaignLevels.byLevelNumber(27)); // early normal, world 2

    expect(afterBoundary.anchorWordCount, lessThanOrEqualTo(beforeBoundary.anchorWordCount));
    expect(afterBoundary.targetCommonRatio, lessThanOrEqualTo(beforeBoundary.targetCommonRatio));
  });

  group('QA: master/finale levels build a solvable board with enough words', () {
    test('every master and worldFinale level produces a board meeting its minWordsRequired', () {
      final specialLevels =
          CampaignLevels.all.where((l) => l.isMasterLevel || l.isWorldFinale).toList();
      expect(specialLevels, isNotEmpty);

      for (final config in specialLevels) {
        final result = builder.buildForLevel(config);
        final profile = BoardDifficultyProfile.forLevel(config);
        expect(
          result.board.possibleWords.length,
          greaterThanOrEqualTo(profile.minWordsRequired),
          reason: 'level ${config.levelNumber} (${config.kind})',
        );
        expect(
          result.board.possibleWords.length,
          greaterThanOrEqualTo(config.wordsRequired),
          reason: 'level ${config.levelNumber} must have enough words to reach its own goal',
        );
      }
    });
  });

  test('no two levels across the full 100-level campaign produce an identical board', () {
    final seenBoards = <String>{};
    for (final config in CampaignLevels.all) {
      final result = builder.buildForLevel(config);
      final key = result.board.letters.map((row) => row.join()).join('|');
      expect(
        seenBoards.contains(key),
        isFalse,
        reason: 'level ${config.levelNumber} produced a duplicate board',
      );
      seenBoards.add(key);
    }
  });
}
