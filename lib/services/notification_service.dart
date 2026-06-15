import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
void onNotificationAction(NotificationResponse response) async {
  if (response.actionId == 'ok_action') {
    final String? currentEventId = response.payload; 
    if (currentEventId != null) {
      const storage = FlutterSecureStorage();
      await storage.write(key: "suppressed_episode_id", value: currentEventId);
      
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(0); 
      await flutterLocalNotificationsPlugin.cancel(1); 
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init({bool isBackground = false}) async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveBackgroundNotificationResponse: onNotificationAction,
      onDidReceiveNotificationResponse: onNotificationAction,
    );

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      if (!isBackground) {
        await androidImplementation.requestNotificationsPermission();
      }

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'cgm_hyper_alerts_v1', 'Wysoki Cukier (Hiperglikemia)',
          description: 'Alerty dla glikemii powyżej normy',
          importance: Importance.max,
        ),
      );
      
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'cgm_hypo_alerts_v1', 'Niski Cukier (Hipoglikemia)',
          description: 'Alerty dla glikemii poniżej normy',
          importance: Importance.max,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'silent_cgm_channel', 'Praca w tle',
          description: 'Utrzymuje działanie aplikacji bez dźwięków i wibracji',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }

    _isInitialized = true;
  }

  Future<void> showHyperNotification(String title, String body, String eventId, bool useVibrations) async {
    final Int64List hyperVibration = Int64List.fromList([0, 2000]);

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cgm_hyper_alerts_v1', 'Wysoki Cukier (Hiperglikemia)',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: useVibrations, 
      vibrationPattern: useVibrations ? hyperVibration : null,
      actions: [const AndroidNotificationAction('ok_action', 'OK (Wycisz epizod)', showsUserInterface: true)],
    );

    await _notificationsPlugin.show(0, title, body, NotificationDetails(android: androidDetails), payload: eventId);
  }

  Future<void> showHypoNotification(String title, String body, String eventId, bool useVibrations) async {
    final Int64List hypoVibration = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cgm_hypo_alerts_v1', 'Niski Cukier (Hipoglikemia)',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: useVibrations, 
      vibrationPattern: useVibrations ? hypoVibration : null,
      actions: [const AndroidNotificationAction('ok_action', 'OK (Wycisz epizod)', showsUserInterface: true)],
    );

    await _notificationsPlugin.show(1, title, body, NotificationDetails(android: androidDetails), payload: eventId);
  }

  Future<void> clearNotification() async {
    await _notificationsPlugin.cancel(0);
    await _notificationsPlugin.cancel(1);
  }
}