import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/case_state.dart';
import 'services/notification_service.dart';
import 'services/iap_service.dart';
import 'screens/case_entry_screen.dart';
import 'screens/ai_check_screen.dart';
import 'screens/action_center_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase and Remote Config
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.setDefaults(const {
      "ad_banner_enabled": true,
      "ad_banner_image_url": "",
      "ad_banner_target_url": "mailto:sampeng0206@gmail.com",
      "ad_banner_link_type": "mailto",
    });
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    debugPrint('Firebase/RemoteConfig initialization failed: $e');
  }

  // Initialize Background & Local Services
  await NotificationService.initialize();
  try {
    await IapService.initialize();
  } catch (e) {
    debugPrint('IapService init failed: $e');
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => CaseState(),
      child: const MoneyBackApp(),
    ),
  );
}

class MoneyBackApp extends StatelessWidget {
  const MoneyBackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyBack 還我錢來',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const CaseEntryScreen(),
        '/ai_check': (context) => const AiCheckScreen(),
        '/action_center': (context) => const ActionCenterScreen(),
      },
    );
  }
}
