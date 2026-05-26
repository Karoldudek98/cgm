import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dexcom_service.dart';
import 'settings_service.dart';
import 'glucose_data_service.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'cgm_foreground',
    'Monitor CGM (W Tle)',
    description: 'Utrzymuje proces monitorowania glikemii przy wyłączonym ekranie.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'cgm_foreground',
      initialNotificationTitle: 'Monitor CGM jest aktywny',
      initialNotificationContent: 'Oczekiwanie na pobranie danych...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await NotificationService().init(isBackground: true);

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
    service.on('stopService').listen((event) => service.stopSelf());
  }

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final dexService = DexcomService();
    
    bool loggedIn = await dexService.initAndLogin();

    if (loggedIn) {
      await SettingsService().loadForUser(dexService.currentUsername);

      final readings = await dexService.getGlucoseHistory();
      
      if (readings.isNotEmpty) {
        final latest = readings.first;
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "CGM Aktywny (W tle)",
            content: "Ostatni odczyt: ${latest.value} mg/dL",
          );
        }

        await GlucoseDataService().processEpisodes(latest);
      }
    }
  });
}