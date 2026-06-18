import 'package:flutter/material.dart';

class AdService {
  static Future<void> initialize() async {}
  static Widget? getBannerAd() => null;
  static Future<void> showInterstitialAd({
    BuildContext? context,
    VoidCallback? onAdDismissed,
  }) async {
    onAdDismissed?.call();
  }
  static void dispose() {}
}

class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
