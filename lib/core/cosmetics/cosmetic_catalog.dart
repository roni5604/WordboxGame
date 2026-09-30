import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum CosmeticSlot { board, letter, marker }

enum MarkerStyle { classic, dashed, pearls, doubleLine, stars }

enum LetterTileShape { circle, roundedSquare }

class BoardSkin extends Equatable {
  final String id;
  final String nameHe;
  final int cost;
  final Color tileColor;
  final Color meshColor;

  /// רקע מעוגל מאחורי האריחים. null = בלי קופסה, כמו הלוח הקלאסי.
  final Color? backdropColor;

  const BoardSkin({
    required this.id,
    required this.nameHe,
    required this.cost,
    required this.tileColor,
    required this.meshColor,
    this.backdropColor,
  });

  @override
  List<Object?> get props => [id, nameHe, cost, tileColor, meshColor, backdropColor];
}

class LetterSkin extends Equatable {
  final String id;
  final String nameHe;
  final int cost;
  final Color letterColor;
  final bool outlined;
  final Color outlineColor;
  final LetterTileShape shape;
  final FontWeight fontWeight;

  /// כשמוגדר, מחליף את צבע האריח של סקין הלוח כדי שהסגנון יישאר קריא.
  final Color? tileOverride;

  const LetterSkin({
    required this.id,
    required this.nameHe,
    required this.cost,
    required this.letterColor,
    required this.outlined,
    required this.outlineColor,
    required this.shape,
    required this.fontWeight,
    this.tileOverride,
  });

  @override
  List<Object?> get props => [
        id,
        nameHe,
        cost,
        letterColor,
        outlined,
        outlineColor,
        shape,
        fontWeight,
        tileOverride,
      ];
}

class MarkerSkin extends Equatable {
  final String id;
  final String nameHe;
  final int cost;
  final MarkerStyle style;
  final Color color;

  const MarkerSkin({
    required this.id,
    required this.nameHe,
    required this.cost,
    required this.style,
    required this.color,
  });

  @override
  List<Object?> get props => [id, nameHe, cost, style, color];
}

class CosmeticCatalog {
  CosmeticCatalog._();

  static const String classicId = 'classic';

  static const List<BoardSkin> boards = [
    BoardSkin(
      id: classicId,
      nameHe: 'קלאסי',
      cost: 0,
      tileColor: Color(0xFFFFD9A0),
      meshColor: Color(0x66FFFFFF),
    ),
    BoardSkin(
      id: 'ocean',
      nameHe: 'אוקיינוס',
      cost: 80,
      tileColor: Color(0xFFB3E5FC),
      meshColor: Color(0xAAE1F5FE),
      backdropColor: Color(0xCC0277BD),
    ),
    BoardSkin(
      id: 'night',
      nameHe: 'לילה',
      cost: 120,
      tileColor: Color(0xFF3949AB),
      meshColor: Color(0x669FA8DA),
      backdropColor: Color(0xEE1A237E),
    ),
    BoardSkin(
      id: 'forest',
      nameHe: 'יער',
      cost: 160,
      tileColor: Color(0xFFC8E6C9),
      meshColor: Color(0xAAE8F5E9),
      backdropColor: Color(0xCC1B5E20),
    ),
    BoardSkin(
      id: 'candy',
      nameHe: 'ממתק',
      cost: 200,
      tileColor: Color(0xFFF8BBD0),
      meshColor: Color(0xAAFCE4EC),
      backdropColor: Color(0xCCAD1457),
    ),
  ];

  static const List<LetterSkin> letters = [
    LetterSkin(
      id: classicId,
      nameHe: 'קלאסי',
      cost: 0,
      letterColor: Color(0xFFE0303B),
      outlined: true,
      outlineColor: Color(0xFFFFFFFF),
      shape: LetterTileShape.circle,
      fontWeight: FontWeight.w900,
    ),
    LetterSkin(
      id: 'navy',
      nameHe: 'לבן על כחול',
      cost: 80,
      letterColor: Color(0xFFFFFFFF),
      outlined: false,
      outlineColor: Color(0xFFFFFFFF),
      shape: LetterTileShape.circle,
      fontWeight: FontWeight.w800,
      tileOverride: Color(0xFF1565C0),
    ),
    LetterSkin(
      id: 'gold',
      nameHe: 'זהב',
      cost: 120,
      letterColor: Color(0xFF4E342E),
      outlined: false,
      outlineColor: Color(0xFFFFF8E1),
      shape: LetterTileShape.circle,
      fontWeight: FontWeight.w800,
      tileOverride: Color(0xFFFFD54F),
    ),
    LetterSkin(
      id: 'rounded',
      nameHe: 'מרובע מעוגל',
      cost: 160,
      letterColor: Color(0xFF4A148C),
      outlined: false,
      outlineColor: Color(0xFFFFFFFF),
      shape: LetterTileShape.roundedSquare,
      fontWeight: FontWeight.w800,
    ),
    LetterSkin(
      id: 'bold',
      nameHe: 'מודגש',
      cost: 200,
      letterColor: Color(0xFFB71C1C),
      outlined: true,
      outlineColor: Color(0xFFFFF59D),
      shape: LetterTileShape.circle,
      fontWeight: FontWeight.w900,
    ),
  ];

  static const List<MarkerSkin> markers = [
    MarkerSkin(
      id: classicId,
      nameHe: 'קו עבה',
      cost: 0,
      style: MarkerStyle.classic,
      color: Color(0xFFFFE066),
    ),
    MarkerSkin(
      id: 'dashed',
      nameHe: 'מקווקו',
      cost: 60,
      style: MarkerStyle.dashed,
      color: Color(0xFF80DEEA),
    ),
    MarkerSkin(
      id: 'pearls',
      nameHe: 'פנינים',
      cost: 100,
      style: MarkerStyle.pearls,
      color: Color(0xFFF8BBD0),
    ),
    MarkerSkin(
      id: 'double',
      nameHe: 'קו כפול',
      cost: 140,
      style: MarkerStyle.doubleLine,
      color: Color(0xFFCE93D8),
    ),
    MarkerSkin(
      id: 'stars',
      nameHe: 'כוכבים',
      cost: 180,
      style: MarkerStyle.stars,
      color: Color(0xFFFFF176),
    ),
  ];

  static BoardSkin boardById(String? id) =>
      boards.firstWhere((s) => s.id == id, orElse: () => boards.first);

  static LetterSkin letterById(String? id) =>
      letters.firstWhere((s) => s.id == id, orElse: () => letters.first);

  static MarkerSkin markerById(String? id) =>
      markers.firstWhere((s) => s.id == id, orElse: () => markers.first);

  static List<String> ownedIdsFor(CosmeticSlot slot, {required bool includeClassic}) {
    final ids = switch (slot) {
      CosmeticSlot.board => boards.map((s) => s.id),
      CosmeticSlot.letter => letters.map((s) => s.id),
      CosmeticSlot.marker => markers.map((s) => s.id),
    };
    if (includeClassic) return ids.toList();
    return ids.where((id) => id != classicId).toList();
  }

  static int costOf(CosmeticSlot slot, String id) {
    return switch (slot) {
      CosmeticSlot.board => boardById(id).cost,
      CosmeticSlot.letter => letterById(id).cost,
      CosmeticSlot.marker => markerById(id).cost,
    };
  }
}

/// מחירי עזרים במטבעות במהלך שלב.
class CoinCosts {
  CoinCosts._();

  static const int revealLetter = 15;
  static const int shuffle = 25;

  static int skipLevel(int levelNumber) => 50 + levelNumber * 2;
}
