import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/pregenerated_level_board.dart';

/// טוען את מפת הלוחות הקבועים (זהים לכל המשתמשים/ות) שנבנו מראש ע"י
/// tool/generate_level_boards.dart - ראו assets/boards/level_boards.json.
///
/// שלבים שלא מוגדרים כאן (מעבר לטווח שנבנה מראש) ייפלו ל-fallback
/// דטרמיניסטי ב-runtime (ראו [GameScreen._initSession]).
final levelBoardsProvider = FutureProvider<Map<int, PregeneratedLevelBoard>>((ref) async {
  final raw = await rootBundle.loadString('assets/boards/level_boards.json');
  final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
  return decoded.map(
    (key, value) => MapEntry(
      int.parse(key),
      PregeneratedLevelBoard.fromJson(value as Map<String, dynamic>),
    ),
  );
});
