import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_engine/dictionary/common_word_pool.dart';

/// טוען את מאגר "המילים הנוחות/מוכרות" (ראו tool/build_common_words.py) -
/// משמש את [LevelBoardBuilder] לבניית לוחות שלבים קבועים ואיכותיים.
final commonWordPoolProvider = FutureProvider<CommonWordPool>((ref) async {
  final raw = await rootBundle.loadString('assets/dictionaries/common_words.json');
  final words = (jsonDecode(raw) as List).cast<String>();
  return CommonWordPool(words.toSet());
});
