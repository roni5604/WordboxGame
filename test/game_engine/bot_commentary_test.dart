import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/bot_commentary.dart';

Duration _s(int s) => Duration(seconds: s);

void main() {
  test('לא יותר מתקרת ההערות, ומרווח בין הערות', () {
    final c = BotCommentary(random: Random(1));
    final said = <Duration>[];
    for (var t = 0; t < 180; t++) {
      final comment = c.onHumanWord(_s(t), letters: 6, displayWord: 'שלומות', bots: const ['עומר']);
      if (comment != null) said.add(_s(t));
    }
    expect(said.length, lessThanOrEqualTo(5));
    for (var i = 1; i < said.length; i++) {
      expect(said[i] - said[i - 1], greaterThanOrEqualTo(const Duration(seconds: 14)));
    }
  });

  test('מילה קצרה של השחקן/ית לא גוררת הערה', () {
    final c = BotCommentary(random: Random(1));
    expect(c.onHumanWord(_s(30), letters: 3, displayWord: 'בית', bots: const ['עומר']), isNull);
  });

  test('עקיפה של השחקן/ית - הבוט נלחץ', () {
    final c = BotCommentary(random: Random(2));
    c.onTick(_s(20), remaining: _s(60), humanScore: 2, botScores: const {'עומר': 6}, humanIdle: Duration.zero);
    final comment = c.onTick(_s(40), remaining: _s(40), humanScore: 9, botScores: const {'עומר': 6}, humanIdle: Duration.zero);
    expect(comment, isNotNull);
    expect(comment!.mood, CommentMood.nervous);
    expect(comment.botName, 'עומר');
  });

  test('20 שניות אחרונות - הערה אחת בלבד', () {
    final c = BotCommentary(random: Random(3));
    var lastMinute = 0;
    for (var t = 70; t < 90; t++) {
      final x = c.onTick(_s(t), remaining: _s(90 - t), humanScore: 5, botScores: const {'נועה': 3}, humanIdle: Duration.zero);
      if (x != null) lastMinute++;
    }
    expect(lastMinute, 1);
  });
}
