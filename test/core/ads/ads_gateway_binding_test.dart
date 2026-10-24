import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/ads/ads_runtime.dart';

import '../../features/ads/fake_ads_gateway.dart';

void main() {
  test('העטיפה מעבירה "מודעה במסך מלא" ומודיעה למאזינים', () {
    final inner = FakeAdsGateway();
    final binding = AdsGatewayBinding(inner);
    var notified = 0;
    binding.addListener(() => notified++);

    expect(binding.isShowingFullScreen, isFalse);
    inner.showingFullScreen = true;
    inner.notifyListeners();
    expect(binding.isShowingFullScreen, isTrue);
    expect(notified, 1);

    binding.dispose();
  });

  test('העטיפה מעבירה רכישה לשער האמיתי', () async {
    final inner = FakeAdsGateway();
    final binding = AdsGatewayBinding(inner);
    await binding.recordPurchase();
    expect(inner.purchasesRecorded, 1);
    binding.dispose();
  });
}
