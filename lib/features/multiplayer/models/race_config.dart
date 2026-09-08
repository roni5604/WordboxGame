import 'package:equatable/equatable.dart';

import '../../../game_engine/bot_player.dart';

/// הגדרות ל"תחרות מקומית" (2-4 משתתפים, לוח משותף, כל אחד/ת מוצא/ת
/// מילים בעצמו/ה - המנצח/ת נקבע/ת לפי ניקוד). ראו lib/game_engine/bot_player.dart
/// להסבר על סימולציית היריבים כל עוד אין שרת רב-משתתפים מחובר.
class BotSetup extends Equatable {
  final String name;
  final BotDifficulty difficulty;

  const BotSetup({required this.name, required this.difficulty});

  @override
  List<Object?> get props => [name, difficulty];
}

class RaceConfig extends Equatable {
  final int gridSize;
  final Duration timeLimit;
  final String humanName;
  final List<BotSetup> bots;

  const RaceConfig({
    required this.gridSize,
    required this.timeLimit,
    required this.humanName,
    required this.bots,
  });

  int get totalPlayers => bots.length + 1;

  @override
  List<Object?> get props => [gridSize, timeLimit, humanName, bots];
}
