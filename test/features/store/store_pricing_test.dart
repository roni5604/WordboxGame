import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/purchases/real_money_catalog.dart';
import 'package:wordbox_hebrew/features/store/widgets/hint_offers.dart';
import 'package:wordbox_hebrew/features/store/widgets/premium_offers.dart';

void main() {
  test('קריאת מחיר מתוויות של החנות בכל המטבעות', () {
    expect(PremiumOffers.parsePrice(r'$2.99'), 2.99);
    expect(PremiumOffers.parsePrice('₪10.90'), 10.90);
    expect(PremiumOffers.parsePrice('3,90 €'), 3.90);
    expect(PremiumOffers.parsePrice(r'$1,299.00'), 1299.0);
    expect(PremiumOffers.parsePrice('חינם'), isNull);
  });

  test('בונוס מחושב לפי המחיר האמיתי מהחנות', () {
    final prices = {
      'wordbox_coins_200': r'$1.99',
      'wordbox_coins_600': r'$2.99',
      'wordbox_coins_1500': r'$6.99',
    };
    String priceOf(RealMoneyPack p) => prices[p.productId] ?? p.fallbackPrice;
    final small = RealMoneyCatalog.byId('wordbox_coins_200')!;
    final medium = RealMoneyCatalog.byId('wordbox_coins_600')!;
    final large = RealMoneyCatalog.byId('wordbox_coins_1500')!;
    expect(PremiumOffers.bonusPercent(small, priceOf), 0);
    expect(PremiumOffers.bonusPercent(medium, priceOf), 100); // 200.7 vs 100.5 מטבעות לדולר
    expect(PremiumOffers.bonusPercent(large, priceOf), 114);
  });

  test('חיסכון בחבילות רמזים מול רמז בודד', () {
    final single = hintPacks.first.cost;
    expect(hintPacks.map((p) => p.savingsPercent(single)).toList(), [0, 10, 17]);
    expect(hintPacks.where((p) => p.bestValue), hasLength(1));
  });
}
