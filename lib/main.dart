import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/case_state.dart';
import 'services/notification_service.dart';
import 'services/iap_service.dart';
import 'screens/case_entry_screen.dart';
import 'screens/ai_check_screen.dart';
import 'screens/action_center_screen.dart';

import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Background & Local Services
  await NotificationService.initialize();
  try {
    await IapService.initialize();
  } catch (e) {
    debugPrint('IapService init failed: $e');
  }
  try {
    await AdService.initialize();
  } catch (e) {
    debugPrint('AdService init failed: $e');
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
