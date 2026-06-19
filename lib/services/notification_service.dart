import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _fcmInitialized = false;

  // Initialize notifications
  static Future<void> initialize() async {
    // 1. Initialize Timezones for scheduling
    try {
      tz.initializeTimeZones();
      // Use local timezone
      final String timeZoneName = 'Asia/Taipei'; // Default to Taiwan
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Timezone initialization failed: $e");
    }

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification clicked: ${response.payload}");
        },
      );
      debugPrint("Local notifications initialized.");
    } catch (e) {
      debugPrint("Local notifications initialization failed: $e");
    }

    // 3. Initialize Firebase & FCM (if config is available, wrapped in try/catch)
    if (!kIsWeb) {
      try {
        // We attempt to initialize Firebase. In a standalone environment, 
        // this will fail if google-services.json or GoogleService-Info.plist are missing.
        // We catch the error so the app continues running without crashing.
        await Firebase.initializeApp();
        
        final FirebaseMessaging messaging = FirebaseMessaging.instance;
        
        // Request FCM permissions
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted FCM permission');
          
          // Get FCM token
          String? token = await messaging.getToken();
          debugPrint('FCM Token: $token');

          // Listen to background messages
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

          // Listen to foreground messages
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            debugPrint('Received a foreground FCM message: ${message.notification?.body}');
            if (message.notification != null) {
              _showImmediateNotification(
                message.notification!.title ?? "MoneyBack 提醒",
                message.notification!.body ?? "",
              );
            }
          });

          _fcmInitialized = true;
        }
      } catch (e) {
        debugPrint("Firebase/FCM initialization skipped or failed: $e. Using local notifications only.");
      }
    }
  }

  // Background FCM handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");
  }

  // Helper to show immediate local notification (e.g. when FCM message is received in foreground)
  static Future<void> _showImmediateNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'moneyback_immediate_channel',
      'MoneyBack Immediate Notifications',
      channelDescription: 'Used for immediate alerts and messages',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _localNotificationsPlugin.show(
        999, // Notification ID
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      debugPrint("Failed to show immediate notification: $e");
    }
  }

  // Schedule a chase reminder (3, 7, 14 days)
  static Future<void> scheduleChaseReminder(int days) async {
    // Cancel any existing reminder first
    await cancelReminder();

    final title = "追款提醒 ⏰";
    final body = "距離你上次催告已過 $days 天，對方仍未回應。你是否需要升級下一步？點擊查看選項。";

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'moneyback_chase_channel',
      'MoneyBack Chase Reminders',
      channelDescription: 'Reminders to follow up on your debt case',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      // Calculate scheduled date/time
      final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(days: days));
      
      await _localNotificationsPlugin.zonedSchedule(
        100, // Notification ID
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint("Chase reminder scheduled in $days days at $scheduledDate");
    } catch (e) {
      // If exact scheduling fails (common on Android 12+ without permissions),
      // we fallback to inexact scheduling or print a warning.
      debugPrint("Failed to schedule exact notification: $e. Attempting standard schedule.");
      try {
        await _localNotificationsPlugin.zonedSchedule(
          100,
          title,
          body,
          tz.TZDateTime.now(tz.local).add(Duration(days: days)),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (innerEx) {
        debugPrint("Fallback scheduling also failed: $innerEx");
      }
    }
  }

  // Trigger a test notification (in 5 seconds) to let users easily verify
  static Future<void> scheduleTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'moneyback_test_channel',
      'MoneyBack Test Notifications',
      channelDescription: 'Test notifications for developer verification',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _localNotificationsPlugin.zonedSchedule(
        101, // Test ID
        "追款提醒 ⏰ (測試)",
        "這是 5 秒測試提醒：距離你上次催告已過數日，對方仍未回應。你是否需要升級下一步？",
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Test notification scheduled to fire in 5 seconds.");
    } catch (e) {
      debugPrint("Failed to schedule test notification: $e");
    }
  }

  // Cancel scheduled reminders
  static Future<void> cancelReminder() async {
    try {
      await _localNotificationsPlugin.cancel(100);
      await _localNotificationsPlugin.cancel(101);
      debugPrint("Reminders cancelled.");
    } catch (e) {
      debugPrint("Failed to cancel reminders: $e");
    }
  }
}
