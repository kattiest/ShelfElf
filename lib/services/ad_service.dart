import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;

  // ── Ad Unit IDs ────────────────────────────────────────────────────────────
  // Test IDs during development — replace with real IDs from admob.google.com
  // before publishing.

  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Google's official test IDs — safe to use during development
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    // TODO: Replace with your real AdMob banner ad unit IDs
    return Platform.isAndroid
        ? 'ca-app-pub-4633288452277147/5716995569' // Android banner
        : 'ca-app-pub-4633288452277147/5716995569'; // iOS banner
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('AdService: failed to initialize — $e');
    }
  }

  /// Create and load a banner ad. Returns null if ads unavailable.
  BannerAd? createBannerAd({required void Function(Ad) onLoaded}) {
    if (!_initialized) return null;
    try {
      return BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner, // 320×50
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: onLoaded,
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner ad failed: ${error.message}');
            ad.dispose();
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService: could not create banner — $e');
      return null;
    }
  }
}
