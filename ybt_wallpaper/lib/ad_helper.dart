import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob helper using official Google test ad unit IDs.
class AdHelper {
  AdHelper._();

  // ── Official Google AdMob Test Ad Unit IDs ──────────────────────
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ── Interstitial Ad Management ──────────────────────────────────
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoading = false;
  static Timer? _usageTimer;
  static final Stopwatch _activeStopwatch = Stopwatch();
  static const int _interstitialIntervalSeconds = 120;
  static int _lastShownAtSeconds = 0;

  /// Initialize the Mobile Ads SDK and start tracking active usage.
  static Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
    _startUsageTracking();
  }

  /// Dispose all ad resources. Call when the app is terminating.
  static void dispose() {
    _usageTimer?.cancel();
    _activeStopwatch.stop();
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// Resume active usage tracking (call from AppLifecycleState.resumed).
  static void resumeTracking() {
    _activeStopwatch.start();
  }

  /// Pause active usage tracking (call from AppLifecycleState.paused).
  static void pauseTracking() {
    _activeStopwatch.stop();
  }

  // ── Internal: Interstitial Loading ──────────────────────────────
  static void _loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(); // Pre-load next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          // Retry after a short delay
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  // ── Internal: Usage Tracking & Showing ──────────────────────────
  static void _startUsageTracking() {
    _activeStopwatch.start();
    _lastShownAtSeconds = 0;

    // Check every second if 10 seconds of active usage has passed
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _activeStopwatch.elapsed.inSeconds;
      final nextThreshold =
          _lastShownAtSeconds + _interstitialIntervalSeconds;

      if (elapsed >= nextThreshold) {
        _showInterstitialAd();
        _lastShownAtSeconds = elapsed;
      }
    });
  }

  static void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      // Ad will be disposed and reloaded via fullScreenContentCallback
    } else {
      // Ad not ready yet, try loading one for the next interval
      _loadInterstitialAd();
    }
  }

  // ── Banner Ad Helper ────────────────────────────────────────────
  /// Creates an [AdWidget]-ready [BannerAd] for a given screen.
  /// Call [BannerAd.load()] after creating.
  static BannerAd createBannerAd({
    void Function(Ad)? onAdLoaded,
    void Function(Ad, LoadAdError)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded ?? (_) {},
        onAdFailedToLoad: onAdFailedToLoad ??
            (ad, error) {
              ad.dispose();
            },
      ),
    );
  }
}
