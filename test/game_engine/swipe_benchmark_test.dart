// מדד דיוק להחלקה (לא חלק מה-CI): מריץ אלפי החלקות "אנושיות" מדומות
// על לוחות בגודל טלפון ומדפיס אחוז הצלחה. מופעל רק עם SWIPE_BENCH=1.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/input/swipe_path_tracker.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';

void main() {
  final enabled = Platform.environment['SWIPE_BENCH'] == '1';

  List<GridPosition> randomPath(math.Random rnd, int size, int length, {bool diagonalHeavy = false}) {
    while (true) {
      final path = <GridPosition>[GridPosition(rnd.nextInt(size), rnd.nextInt(size))];
      var ok = true;
      while (path.length < length) {
        final last = path.last;
        final options = [
          for (final n in last.rawNeighbors)
            if (n.row >= 0 && n.row < size && n.col >= 0 && n.col < size && !path.contains(n))
              if (!diagonalHeavy || (n.row != last.row && n.col != last.col) || rnd.nextDouble() < 0.25) n,
        ];
        if (options.isEmpty) {
          ok = false;
          break;
        }
        path.add(options[rnd.nextInt(options.length)]);
      }
      if (ok) return path;
    }
  }

  /// [startOffset] - כמה פיקסלים לאורך המקטע הראשון "מתחילה" ההחלקה
  /// (מדמה את ה-pan slop של Flutter כשמשתמשים ב-onPanStart).
  (bool primary, bool withDict) run(
    List<GridPosition> cells, {
    required double cell,
    required int size,
    required math.Random rnd,
    double jitter = 0.1,
    double bow = 0.15,
    double startOffset = 0,
    double aimError = 0.12,
    Offset bias = Offset.zero,
    int minSamples = 4,
    int maxExtraSamples = 12,
    double overshoot = 0,
    List<String>? failures,
  }) {
    Offset center(GridPosition p) => Offset(p.col * cell + cell / 2, p.row * cell + cell / 2);
    // האצבע מכוונת לאות אבל לא בדיוק למרכז.
    final aims = [
      for (final c in cells)
        center(c) + bias * cell + Offset((rnd.nextDouble() * 2 - 1) * aimError * cell, (rnd.nextDouble() * 2 - 1) * aimError * cell),
    ];
    if (overshoot > 0) {
      // האצבע ממשיכה מעט אחרי האות האחרונה לפני שהיא מתרוממת.
      final d = aims.last - aims[aims.length - 2];
      aims.add(aims.last + d / d.distance * overshoot * cell);
    }
    final tracker = SwipePathTracker(size: size, cellSize: cell);
    final firstDir = aims[1] - aims[0];
    tracker.start(aims[0] + firstDir / firstDir.distance * startOffset);
    for (int s = 1; s < aims.length; s++) {
      final a = aims[s - 1];
      final b = aims[s];
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final segBow = (rnd.nextDouble() * 2 - 1) * bow * cell;
      final samples = minSamples + rnd.nextInt(maxExtraSamples + 1);
      for (int i = 1; i <= samples; i++) {
        final t = i / samples;
        final arc = math.sin(t * math.pi) * segBow;
        final noise = (rnd.nextDouble() * 2 - 1) * jitter * cell * math.sin(t * math.pi);
        tracker.move(Offset.lerp(a, b, t)! + normal * (arc + noise));
      }
    }
    final candidates = tracker.candidatePaths();
    final primary = tracker.end();
    final key = cells.toString();
    // (aims כולל נקודת overshoot, אבל המטרה היא רק cells)
    if (failures != null && primary.toString() != key && failures.length < 4000) {
      final extra = primary.where((c) => !cells.contains(c)).length;
      final missing = cells.where((c) => !primary.contains(c)).length;
      final kind = primary.isEmpty
          ? 'empty'
          : primary.first != cells.first
              ? 'wrong-start'
              : extra > 0 && missing == 0
                  ? (primary.last != cells.last ? 'extra-at-end' : 'extra-in-middle')
                  : missing > 0 && extra == 0
                      ? (primary.last != cells.last ? 'missing-last' : 'missing-mid')
                      : 'swapped';
      failures.add(kind);
    }
    return (primary.toString() == key, candidates.any((c) => c.toString() == key));
  }

  test('swipe benchmark', () {
    final out = StringBuffer();
    for (final scenario in [
      (name: '5x5 cell 64 no-slop', size: 5, cell: 64.0, slop: 0.0, diag: false),
      (name: '5x5 cell 64 slop36', size: 5, cell: 64.0, slop: 36.0, diag: false),
      (name: '7x7 cell 48 no-slop', size: 7, cell: 48.0, slop: 0.0, diag: false),
      (name: '7x7 cell 48 slop36', size: 7, cell: 48.0, slop: 36.0, diag: false),
      (name: '7x7 cell 48 diag-heavy', size: 7, cell: 48.0, slop: 0.0, diag: true),
      (name: '6x6 cell 56 diag-heavy sloppy', size: 6, cell: 56.0, slop: 0.0, diag: true),
      (name: '7x7 cell 48 diag finger-bias', size: 7, cell: 48.0, slop: 0.0, diag: true),
      (name: '7x7 cell 48 diag fast', size: 7, cell: 48.0, slop: 0.0, diag: true),
      (name: '7x7 cell 48 diag overshoot', size: 7, cell: 48.0, slop: 0.0, diag: true),
      (name: '7x7 cell 48 diag everything', size: 7, cell: 48.0, slop: 0.0, diag: true),
    ]) {
      final rnd = math.Random(42);
      var primary = 0, dict = 0;
      final failures = <String>[];
      const n = 3000;
      final sloppy = scenario.name.contains('sloppy') || scenario.name.contains('everything');
      for (int i = 0; i < n; i++) {
        final path = randomPath(rnd, scenario.size, 3 + rnd.nextInt(4), diagonalHeavy: scenario.diag);
        final nm = scenario.name;
        final all = nm.contains('everything');
        final (p, d) = run(
          path,
          cell: scenario.cell,
          size: scenario.size,
          rnd: rnd,
          startOffset: scenario.slop,
          jitter: sloppy ? 0.16 : 0.1,
          bow: sloppy ? 0.22 : 0.15,
          aimError: sloppy || all ? 0.18 : 0.12,
          bias: nm.contains('bias') || all ? const Offset(0.04, 0.16) : Offset.zero,
          minSamples: nm.contains('fast') || all ? 1 : 4,
          maxExtraSamples: nm.contains('fast') || all ? 2 : 12,
          overshoot: nm.contains('overshoot') || all ? 0.45 : 0,
          failures: failures,
        );
        if (p) primary++;
        if (d) dict++;
      }
      out.writeln(
        '${scenario.name.padRight(32)} primary ${(primary * 100 / n).toStringAsFixed(1)}%  '
        'with-dictionary ${(dict * 100 / n).toStringAsFixed(1)}%  '
        '${{for (final f in failures.toSet()) f: failures.where((x) => x == f).length}}',
      );
    }
    // ignore: avoid_print
    print(out);
  }, skip: !enabled);
}
