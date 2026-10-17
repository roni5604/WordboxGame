import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../analytics/analytics_service.dart';
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
        _analytics.purchaseFailed(productId: 'unknown', reason: 'stream_error');
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

  String? _obfuscatedAccountId() {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || uid.isEmpty) return null;
    return sha256.convert(utf8.encode('wordbox-iap:$uid')).toString();
  }

  AnalyticsService get _analytics => _ref.read(analyticsProvider);

  /// Analytics: purchase_start when the store sheet is requested, and
  /// purchase_failed (product_id, reason) for every way it can fail. The
  /// successful purchase itself is logged automatically on mobile by
  /// Firebase as `in_app_purchase` (with revenue), so it is not logged here.
  Future<String?> buy(String productId) async {
    if (kIsWeb || state.isWeb) {
      return 'הרכישה זמינה באפליקציה ל-iPhone ולאנדרואיד';
    }
    _analytics.purchaseStart(productId: productId);
    final product = _products[productId];
    if (!state.available || product == null) {
      _analytics.purchaseFailed(productId: productId, reason: 'store_unavailable');
      return 'החנות לא זמינה כרגע';
    }
    var started = false;
    try {
      started = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          // מזהה חשבון מוסתר (hash) - עוזר לחנויות לזהות הונאות ומאפשר
          // בעתיד אימות קבלות בשרת, בלי לחשוף את ה-uid עצמו.
          applicationUserName: _obfuscatedAccountId(),
        ),
      );
    } catch (_) {
      _analytics.purchaseFailed(productId: productId, reason: 'start_exception');
      return 'לא ניתן להתחיל את הרכישה';
    }
    if (!started) {
      _analytics.purchaseFailed(productId: productId, reason: 'not_started');
      return 'לא ניתן להתחיל את הרכישה';
    }
    return null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // למשל תשלום במזומן/אישור הורה ב-Google Play - הזיכוי יגיע כשיאושר.
          state = state.copyWith(message: 'הרכישה ממתינה לאישור. החבילה תתווסף ברגע שתאושר');
        case PurchaseStatus.canceled:
          _analytics.purchaseFailed(productId: purchase.productID, reason: 'user_canceled');
          await _completeIfNeeded(purchase);
        case PurchaseStatus.error:
          final code = purchase.error?.code;
          _analytics.purchaseFailed(
            productId: purchase.productID,
            reason: code == null || code.isEmpty ? 'error' : 'error_$code',
          );
          state = state.copyWith(message: 'הרכישה לא הושלמה');
          await _completeIfNeeded(purchase);
        case PurchaseStatus.restored:
          await _completeIfNeeded(purchase);
        case PurchaseStatus.purchased:
          await _grant(purchase);
      }
    }
  }

  static const _grantedPrefsKey = 'iap_granted_purchase_ids';

  /// מזהי רכישות שכבר זוכו - נשמרים במכשיר כדי שרכישה שהחנות שולחת שוב
  /// (למשל אם האפליקציה נסגרה לפני completePurchase) לא תזוכה פעמיים.
  Future<bool> _alreadyGranted(String key) async {
    if (_handled.contains(key)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final granted = prefs.getStringList(_grantedPrefsKey) ?? const <String>[];
      if (granted.contains(key)) {
        _handled.add(key);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _recordGranted(String key) async {
    _handled.add(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      final granted = [...?prefs.getStringList(_grantedPrefsKey), key];
      // שומרים רק את האחרונות - מספיק כדי לזהות שליחה חוזרת.
      final trimmed = granted.length > 200 ? granted.sublist(granted.length - 200) : granted;
      await prefs.setStringList(_grantedPrefsKey, trimmed);
    } catch (_) {}
  }

  Future<void> _grant(PurchaseDetails purchase) async {
    final key = purchase.purchaseID ?? '${purchase.productID}:${purchase.transactionDate}';
    final pack = RealMoneyCatalog.byId(purchase.productID);
    if (pack != null && !await _alreadyGranted(key)) {
      try {
        await _ref.read(playerProfileProvider.notifier).grantRealMoneyReward(
              coins: pack.coins,
              hints: pack.hints,
            );
      } catch (_) {
        // לא מסיימים את הרכישה מול החנות - היא תישלח שוב בהפעלה הבאה
        // ותזוכה אז, במקום שהשחקן/ית ישלם/תשלם ולא יקבל/תקבל כלום.
        state = state.copyWith(message: 'הרכישה התקבלה ותתווסף בהפעלה הבאה');
        return;
      }
      await _recordGranted(key);
      _analytics
        ..markPayer()
        ..earnVirtualCurrency(currency: 'coins', value: pack.coins, source: 'purchase', item: pack.productId)
        ..earnVirtualCurrency(currency: 'hints', value: pack.hints, source: 'purchase', item: pack.productId);
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
