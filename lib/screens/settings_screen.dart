import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/settings_service.dart';
import '../widgets/glucose_thresholds_widget.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ustawienia"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const GlucoseThresholdsWidget(),
          const Divider(),
          
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService().isMmolLNotifier,
            builder: (context, isMmol, _) {
              return SwitchListTile(
                title: const Text("Jednostki mmol/L"),
                subtitle: const Text("Zmień jednostki z mg/dL na mmol/L"),
                value: isMmol,
                onChanged: (val) {
                  SettingsService().toggleMmolL(val);
                },
              );
            },
          ),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService().isVibrationsEnabledNotifier,
            builder: (context, isVibesEnabled, _) {
              return SwitchListTile(
                title: const Text("Wibracje alarmów"),
                subtitle: const Text("Używaj wibracji przy powiadomieniach"),
                value: isVibesEnabled,
                onChanged: (val) {
                  SettingsService().toggleVibrations(val);
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text("Zarządzaj dźwiękami alarmów"),
            subtitle: const Text("Zmień dźwięk powiadomień dla wysokiego i niskiego cukru w ustawieniach systemu"),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
          ),
          
          const Divider(height: 40, thickness: 2),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              "Wyloguj się",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Twoje ustawienia zostaną zachowane na tym urządzeniu."),
            onTap: () async {
              final service = FlutterBackgroundService();
              var isRunning = await service.isRunning();
              if (isRunning) {
                service.invoke("stopService");
              }

              const storage = FlutterSecureStorage();
              await storage.delete(key: "active_username"); 
              await storage.delete(key: "session_id");

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}