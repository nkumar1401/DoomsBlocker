import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge.dart';

/// Manages Kids Mode 9-day trial, Google Play Billing (₹9/year prepaid pass), and test simulations.
class SubscriptionService {
  static const String productId = 'doomsblocker_kids_annual_9inr';
  static const String altProductId = 'kids_mode_annual';
  static const String prepaidProductId = 'kids_mode_annual_prepaid';
  static const String altPrepaidProductId = 'doomsblocker_kids_annual_prepaid';
  static const Set<String> productIds = {productId, altProductId, prepaidProductId, altPrepaidProductId};

  static const String _keyTrialInstalledAt = 'subscription_trial_installed_at';
  static const String _keySubscriptionExpiresAt = 'subscription_expires_at';
  static const String _keyLastPurchasedEmail = 'subscription_purchased_email';
  static const String _keyNotified48h = 'subscription_notified_48h';
  static const String _keyNotified24h = 'subscription_notified_24h';

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  int _trialInstalledAt = 0;
  int _subscriptionExpiresAt = 0;
  String? _purchasedEmail;
  bool _isAvailable = false;
  ProductDetails? _kidsProduct;

  int get trialInstalledAt => _trialInstalledAt;
  int get subscriptionExpiresAt => _subscriptionExpiresAt;
  String? get purchasedEmail => _purchasedEmail;
  ProductDetails? get kidsProduct => _kidsProduct;

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  /// Days remaining in the 9-day trial (0 to 9)
  int get trialDaysRemaining {
    if (_trialInstalledAt == 0) return 9;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMillis = now - _trialInstalledAt;
    final elapsedDays = (elapsedMillis / (1000 * 60 * 60 * 24)).floor();
    final remaining = 9 - elapsedDays;
    return remaining.clamp(0, 9);
  }

  /// Whether the 9-day free trial is currently active
  bool get isKidsTrialActive => trialDaysRemaining > 0;

  /// Whether the user has an active paid subscription (₹9/year prepaid pass)
  bool get isKidsSubscribed {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _subscriptionExpiresAt > now;
  }

  /// Days remaining on the 1-Year Prepaid Pass (0 to 365)
  int get prepaidDaysRemaining {
    if (_subscriptionExpiresAt == 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = _subscriptionExpiresAt - now;
    if (remainingMillis <= 0) return 0;
    final days = (remainingMillis / (1000 * 60 * 60 * 24)).ceil();
    return days.clamp(0, 365);
  }

  /// Hours remaining on the 1-Year Prepaid Pass
  int get prepaidHoursRemaining {
    if (_subscriptionExpiresAt == 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = _subscriptionExpiresAt - now;
    if (remainingMillis <= 0) return 0;
    return (remainingMillis / (1000 * 60 * 60)).ceil();
  }

  /// Whether Kids Mode features can be toggled or used
  bool get canAccessKidsMode => isKidsTrialActive || isKidsSubscribed;

  /// Initialize trial timestamp, local subscription state, and Google Play connection
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _trialInstalledAt = prefs.getInt(_keyTrialInstalledAt) ?? 0;
    if (_trialInstalledAt == 0) {
      _trialInstalledAt = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyTrialInstalledAt, _trialInstalledAt);
    }

    _subscriptionExpiresAt = prefs.getInt(_keySubscriptionExpiresAt) ?? 0;
    _purchasedEmail = prefs.getString(_keyLastPurchasedEmail);

    _initIAP();
  }

  void _initIAP() {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (err) => debugPrint('[SubscriptionService] IAP Stream error: $err'),
    );

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('[SubscriptionService] Google Play Billing not available on device');
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[SubscriptionService] Products ${response.notFoundIDs} not found in Play Console yet');
      }
      if (response.productDetails.isNotEmpty) {
        _kidsProduct = response.productDetails.first;
        debugPrint('[SubscriptionService] Loaded product: ${_kidsProduct?.title} (${_kidsProduct?.price})');
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error loading products: $e');
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        await _grantAnnualSubscription(purchase);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[SubscriptionService] Purchase error: ${purchase.error?.message}');
      }
    }
  }

  Future<void> _grantAnnualSubscription(PurchaseDetails purchase) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneYearMillis = _oneYearInMillis(now);
    _subscriptionExpiresAt = oneYearMillis;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubscriptionExpiresAt, _subscriptionExpiresAt);
    await prefs.setBool(_keyNotified48h, false);
    await prefs.setBool(_keyNotified24h, false);

    _statusController.add(true);
    debugPrint('[SubscriptionService] Successfully granted 1-year Kids Mode prepaid pass!');
  }

  /// Checks if prepaid pass is nearing expiry and triggers local push notifications at 48h and 24h
  Future<void> checkAndTriggerExpiryNotifications() async {
    if (!isKidsSubscribed) return;

    final hours = prepaidHoursRemaining;
    final prefs = await SharedPreferences.getInstance();
    final notified48h = prefs.getBool(_keyNotified48h) ?? false;
    final notified24h = prefs.getBool(_keyNotified24h) ?? false;

    if (hours <= 48 && hours > 24 && !notified48h) {
      await NativeBridge.showLocalNotification(
        title: 'Parental Controls Plan Expiring Soon',
        body: 'Your 1-Year Parental Controls pass expires in 2 days. Tap to recharge for ₹9 with zero auto-debit.',
        id: 2048,
      );
      await prefs.setBool(_keyNotified48h, true);
      debugPrint('[SubscriptionService] Fired 48h expiry reminder notification');
    } else if (hours <= 24 && hours > 0 && !notified24h) {
      await NativeBridge.showLocalNotification(
        title: 'Parental Controls Plan Expiring Tomorrow',
        body: 'Your 1-Year Parental Controls pass expires in 24 hours. Tap to recharge for ₹9 and maintain focus protection.',
        id: 2024,
      );
      await prefs.setBool(_keyNotified24h, true);
      debugPrint('[SubscriptionService] Fired 24h expiry reminder notification');
    }
  }

  static int _oneYearInMillis(int startMillis) {
    return startMillis + (365 * 24 * 60 * 60 * 1000);
  }

  /// Launch Google Play Billing checkout sheet for ₹9/year
  Future<bool> buyKidsSubscription() async {
    if (_kidsProduct != null) {
      final purchaseParam = PurchaseParam(productDetails: _kidsProduct!);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // If product not published yet in Play Console, simulate purchase for testing
      debugPrint('[SubscriptionService] Product not live on Play Console, executing test purchase');
      await simulateMockPurchase();
      return true;
    }
  }

  /// Restore existing purchase across reinstalls or phone changes
  Future<void> restorePurchases() async {
    try {
      if (_isAvailable) {
        await _iap.restorePurchases();
      } else {
        // Offline / local restore check
        final prefs = await SharedPreferences.getInstance();
        _subscriptionExpiresAt = prefs.getInt(_keySubscriptionExpiresAt) ?? 0;
        _statusController.add(isKidsSubscribed);
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error restoring purchases: $e');
    }
  }

  // ==========================================
  // 🧪 DEVELOPER TESTING & SIMULATION SUITE
  // ==========================================

  /// Fast-forwards the clock to Day 10 (Trial Expired) to immediately test paywall
  Future<void> simulateDay10Expiry() async {
    final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch;
    _trialInstalledAt = tenDaysAgo;
    _subscriptionExpiresAt = 0; // Not subscribed

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTrialInstalledAt, _trialInstalledAt);
    await prefs.setInt(_keySubscriptionExpiresAt, 0);

    _statusController.add(false);
    debugPrint('[SubscriptionService] Simulating Day 10: Trial Expired!');
  }

  /// Simulates a successful ₹9.00 payment
  Future<void> simulateMockPurchase([String parentEmail = 'parent.test@gmail.com']) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _subscriptionExpiresAt = now + (365 * 24 * 60 * 60 * 1000);
    _purchasedEmail = parentEmail;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubscriptionExpiresAt, _subscriptionExpiresAt);
    await prefs.setString(_keyLastPurchasedEmail, parentEmail);
    await prefs.setBool(_keyNotified48h, false);
    await prefs.setBool(_keyNotified24h, false);

    _statusController.add(true);
    debugPrint('[SubscriptionService] Mock Purchase successful: 365 days granted for $parentEmail');
  }

  /// Resets trial back to Day 1 (9 full days remaining)
  Future<void> resetTrialToDay1() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _trialInstalledAt = now;
    _subscriptionExpiresAt = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTrialInstalledAt, _trialInstalledAt);
    await prefs.setInt(_keySubscriptionExpiresAt, 0);

    _statusController.add(false);
    debugPrint('[SubscriptionService] Reset trial to Day 1 (9 days remaining)');
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
