import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
void onNotificationAction(NotificationResponse response) async {
  if (response.actionId == 'ok_action') {
    final String? currentEventId = response.payload; // Odbieramy ID naszego epizodu
    
    if (currentEventId != null) {
      const storage = FlutterSecureStorage();
      await storage.write(key: "suppressed_episode_id", value: currentEventId);
      
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(0);
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveBackgroundNotificationResponse: onNotificationAction,
      onDidReceiveNotificationResponse: onNotificationAction,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> showGlucoseNotification(String title, String body, String eventId) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cgm_alerts', 
      'Alerty CGM',
      channelDescription: 'Powiadomienia o przekroczonych zakresach',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, 
      enableVibration: false, 
      actions: [
        AndroidNotificationAction(
          'ok_action', 
          'OK',
          showsUserInterface: true, 
        ),
      ],
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(0, title, body, details, payload: eventId);
  }

  Future<void> clearNotification() async {
    await _notificationsPlugin.cancel(0);
  }
}