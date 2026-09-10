// ignore_for_file: avoid_print
//
// בונה מראש (build-time) לוח קבוע ואיכותי לכל שלב מוגדר בקמפיין, ושומר
// אותם ל-assets/boards/level_boards.json - כדי שכל המשתמשים/ות יקבלו
// בדיוק את אותו לוח בכל שלב (ראו lib/game_engine/level_board_builder.dart
// להסבר המלא על האלגוריתם).
//
// סקריפט Dart טהור (בלי תלות ב-Flutter) - מריצים אותו עם:
//     dart run tool/generate_level_boards.dart
//
// יש להריץ מחדש כל פעם שהמילון (assets/dictionaries/he_words.json) או
// מאגר המילים הנוחות (assets/dictionaries/common_words.json) מתעדכנים.

import 'dart:convert';
import 'dart:io';

import 'package:wordbox_hebrew/game_engine/dictionary/common_word_pool.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/level_board_builder.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

final _root = Directory.current.path;

Future<void> main() async {
  final dictionaryFile = File('$_root/assets/dictionaries/he_words.json');
  final commonWordsFile = File('$_root/assets/dictionaries/common_words.json');
  final frequencyFile = File('$_root/assets/config/letter_frequency.json');
  final outFile = File('$_root/assets/boards/level_boards.json');

  final words = (jsonDecode(await dictionaryFile.readAsString()) as List).cast<String>();
  final commonWords =
      (jsonDecode(await commonWordsFile.readAsString()) as List).cast<String>();
  final Map<String, dynamic> freqRaw =
      jsonDecode(await frequencyFile.readAsString()) as Map<String, dynamic>;
  final letterWeights = freqRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));

  final trie = HebrewTrie()..insertAll(words);
  final pool = CommonWordPool(commonWords.toSet());
  final builder = LevelBoardBuilder(trie: trie, letterWeights: letterWeights, commonWords: pool);

  final output = <String, dynamic>{};

  print('בונה לוחות קבועים ל-${CampaignLevels.all.length} שלבים...');
  for (final config in CampaignLevels.all) {
    final result = builder.buildForLevel(config);
    final board = result.board;

    final entry = <String, dynamic>{
      'size': board.size,
      'letters': board.letters,
    };

    // רק שלב 1 מקבל מילת/נתיב טוטוריאל - זו המילה הקצרה ביותר מבין
    // העוגנים המוכרים שהוצבו בהצלחה בלוח, לצורך ההדגמה המוטבעת בתחילת
    // השלב (ראו lib/features/game/game_screen.dart).
    if (config.levelNumber == 1 && result.anchors.isNotEmpty) {
      final shortest = result.anchors.reduce(
        (a, b) => a.normalizedWord.length <= b.normalizedWord.length ? a : b,
      );
      entry['tutorialWord'] = shortest.normalizedWord;
      entry['tutorialPath'] = shortest.path.map((p) => [p.row, p.col]).toList();
    }

    output[config.levelNumber.toString()] = entry;

    final commonCount =
        board.possibleWords.where((w) => pool.isCommon(w.normalizedWord)).length;
    print(
      '  שלב ${config.levelNumber} (${board.size}x${board.size}): '
      '${board.possibleWords.length} מילים אפשריות ($commonCount מוכרות), '
      '${result.anchors.length} עוגנים הוצבו בהצלחה'
      '${config.isMilestoneLevel ? "  ⭐ אבן דרך" : ""}',
    );
  }

  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(jsonEncode(output));
  print('✅ ${output.length} לוחות קבועים נכתבו ל-${outFile.path}');
}
