import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/case_state.dart';

class AdService {
  static const String appId = "ca-app-pub-3755777658581400~8662367884";
  static const String bannerAdUnitId = "ca-app-pub-3755777658581400/9592306171";
  static const String interstitialAdUnitId = "ca-app-pub-3755777658581400/2835326136";

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static void showInterstitialAd({
    required BuildContext context,
    required VoidCallback onAdDismissed,
  }) {
    final state = Provider.of<CaseState>(context, listen: false);
    if (state.isPremium) {
      onAdDismissed();
      return;
    }

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdDismissed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (err) {
          onAdDismissed();
        },
      ),
    );
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  void _loadAd() {
    final state = Provider.of<CaseState>(context, listen: false);
    if (state.isPremium) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
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
    final state = Provider.of<CaseState>(context);
    if (state.isPremium || _bannerAd == null || !_isLoaded) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
