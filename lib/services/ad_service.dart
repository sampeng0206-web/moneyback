import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _iosBannerAdUnitId = 'ca-app-pub-3755777658581400/9592306171';
  static const String _androidBannerAdUnitId = 'ca-app-pub-3755777658581400/3683410892';

  static const String _iosInterstitialAdUnitId = 'ca-app-pub-3755777658581400/2835326136';
  static const String _androidInterstitialAdUnitId = 'ca-app-pub-3755777658581400/3916832301';

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoading = false;

  static String get _bannerAdUnitId => Platform.isIOS ? _iosBannerAdUnitId : _androidBannerAdUnitId;
  static String get _interstitialAdUnitId => Platform.isIOS ? _iosInterstitialAdUnitId : _androidInterstitialAdUnitId;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  static void _loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint("Interstitial ad failed to load: $error");
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  static Widget? getBannerAd() {
    return const BannerAdWidget();
  }

  static Future<void> showInterstitialAd({
    BuildContext? context,
    VoidCallback? onAdDismissed,
  }) async {
    if (_interstitialAd == null) {
      onAdDismissed?.call();
      _loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onAdDismissed?.call();
      },
    );

    await _interstitialAd!.show();
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService._bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
