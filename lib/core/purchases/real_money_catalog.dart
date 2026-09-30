import 'package:equatable/equatable.dart';

/// חבילת consumable ל-App Store / Google Play.
/// המחיר בפועל נקבע בקונסולות; [fallbackPrice] מוצג כשהחנות לא החזירה מחיר.
class RealMoneyPack extends Equatable {
  final String productId;
  final String titleHe;
  final String subtitleHe;
  final String fallbackPrice;
  final int coins;
  final int hints;

  const RealMoneyPack({
    required this.productId,
    required this.titleHe,
    required this.subtitleHe,
    required this.fallbackPrice,
    this.coins = 0,
    this.hints = 0,
  });

  @override
  List<Object?> get props => [productId, titleHe, subtitleHe, fallbackPrice, coins, hints];
}

class RealMoneyCatalog {
  RealMoneyCatalog._();

  static const List<RealMoneyPack> packs = [
    RealMoneyPack(
      productId: 'wordbox_coins_200',
      titleHe: '200 מטבעות',
      subtitleHe: 'חבילה קטנה',
      fallbackPrice: r'$0.99',
      coins: 200,
    ),
    RealMoneyPack(
      productId: 'wordbox_coins_600',
      titleHe: '600 מטבעות',
      subtitleHe: 'חבילה בינונית',
      fallbackPrice: r'$1.99',
      coins: 600,
    ),
    RealMoneyPack(
      productId: 'wordbox_coins_1500',
      titleHe: '1500 מטבעות',
      subtitleHe: 'חבילה גדולה',
      fallbackPrice: r'$3.99',
      coins: 1500,
    ),
    RealMoneyPack(
      productId: 'wordbox_hints_5',
      titleHe: '5 רמזים',
      subtitleHe: 'חבילת רמזים קטנה',
      fallbackPrice: r'$0.99',
      hints: 5,
    ),
    RealMoneyPack(
      productId: 'wordbox_hints_15',
      titleHe: '15 רמזים',
      subtitleHe: 'חבילת רמזים בינונית',
      fallbackPrice: r'$1.99',
      hints: 15,
    ),
    RealMoneyPack(
      productId: 'wordbox_hints_40',
      titleHe: '40 רמזים',
      subtitleHe: 'חבילת רמזים גדולה',
      fallbackPrice: r'$3.99',
      hints: 40,
    ),
  ];

  static Set<String> get productIds => packs.map((p) => p.productId).toSet();

  static RealMoneyPack? byId(String productId) {
    for (final pack in packs) {
      if (pack.productId == productId) return pack;
    }
    return null;
  }
}
