import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../providers/player_profile_provider.dart';
import 'real_money_catalog.dart';

class IapState {
  final bool ready;
  final bool available;
  final bool isWeb;
  final Map<String, String> prices;
  final String? message;

  const IapState({
    this.ready = false,
    this.available = false,
    this.isWeb = false,
    this.prices = const {},
    this.message,
  });

  IapState copyWith({
    bool? ready,
    bool? available,
    bool? isWeb,
    Map<String, String>? prices,
    String? message,
    bool clearMessage = false,
  }) {
    return IapState(
      ready: ready ?? this.ready,
      available: available ?? this.available,
      isWeb: isWeb ?? this.isWeb,
      prices: prices ?? this.prices,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  String priceLabel(RealMoneyPack pack) => prices[pack.productId] ?? pack.fallbackPrice;
}

class IapController extends StateNotifier<IapState> {
  IapController(this._ref, {bool autoInit = true}) : super(const IapState()) {
    if (autoInit) _init();
  }

  final Ref _ref;
  final Map<String, ProductDetails> _products = {};
  final Set<String> _handled = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> _init() async {
    if (kIsWeb) {
      state = state.copyWith(ready: true, isWeb: true, available: false);
      return;
    }

    final billing = InAppPurchase.instance;
    _subscription = billing.purchaseStream.listen(
      _onPurchases,
      onError: (Object _) {
        state = state.copyWith(message: 'הרכישה לא הושלמה');
      },
    );

    final available = await billing.isAvailable();
    if (!available) {
      state = state.copyWith(ready: true, available: false);
      return;
    }

    final response = await billing.queryProductDetails(RealMoneyCatalog.productIds);
    _products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
    state = state.copyWith(
      ready: true,
      available: _products.isNotEmpty,
      prices: {for (final p in response.productDetails) p.id: p.price},
    );
  }

  Future<String?> buy(String productId) async {
    if (kIsWeb || state.isWeb) {
      return 'הרכישה זמינה באפליקציה ל-iPhone ולאנדרואיד';
    }
    final product = _products[productId];
    if (!state.available || product == null) {
      return 'החנות לא זמינה כרגע';
    }
    final started = await InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) return 'לא ניתן להתחיל את הרכישה';
    return null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          await _completeIfNeeded(purchase);
        case PurchaseStatus.error:
          state = state.copyWith(message: 'הרכישה לא הושלמה');
          await _completeIfNeeded(purchase);
        case PurchaseStatus.restored:
          await _completeIfNeeded(purchase);
        case PurchaseStatus.purchased:
          await _grant(purchase);
      }
    }
  }

  Future<void> _grant(PurchaseDetails purchase) async {
    final key = purchase.purchaseID ?? '${purchase.productID}:${purchase.transactionDate}';
    final pack = RealMoneyCatalog.byId(purchase.productID);
    if (pack != null && _handled.add(key)) {
      await _ref.read(playerProfileProvider.notifier).grantRealMoneyReward(
            coins: pack.coins,
            hints: pack.hints,
          );
      final what = pack.hints > 0 ? '${pack.hints} רמזים' : '${pack.coins} מטבעות';
      state = state.copyWith(message: 'נוספו $what');
    }
    await _completeIfNeeded(purchase);
  }

  Future<void> _completeIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final iapProvider = StateNotifierProvider<IapController, IapState>((ref) {
  return IapController(ref);
});
