import 'package:equatable/equatable.dart';

/// מיקום תא בודד בלוח האותיות (שורה, עמודה) - שתיהן מבוססות אינדקס 0.
class GridPosition extends Equatable {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  /// כל 8 השכנים האפשריים (אופקי / אנכי / אלכסוני) - ללא בדיקת גבולות הלוח.
  List<GridPosition> get rawNeighbors => [
        GridPosition(row - 1, col - 1),
        GridPosition(row - 1, col),
        GridPosition(row - 1, col + 1),
        GridPosition(row, col - 1),
        GridPosition(row, col + 1),
        GridPosition(row + 1, col - 1),
        GridPosition(row + 1, col),
        GridPosition(row + 1, col + 1),
      ];

  bool isAdjacentTo(GridPosition other) {
    final dr = (row - other.row).abs();
    final dc = (col - other.col).abs();
    return dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0);
  }

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => '($row,$col)';
}
